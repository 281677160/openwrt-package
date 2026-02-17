'use strict';
'require fs';
'require ui';
'require view';
'require poll';
'require uci';

return view.extend({
    _state: 'idle',
    _polling: false,
    _pollFn: null,
    _flashBtn: null,
    _statusEl: null,
    _logEl: null,

    load: function() {
        return Promise.all([
            L.resolveDefault(fs.exec('/usr/bin/qfirehose'), {}),
            L.resolveDefault(fs.list('/dev'), []),
            L.resolveDefault(fs.list('/sys/bus/usb/devices'), []),
            L.resolveDefault(fs.exec('/usr/sbin/qfirehose-status'), {}),
            uci.load('qfirehose'),
            L.resolveDefault(fs.exec('/usr/sbin/qfirehose-modem-info'), {})
        ]);
    },

    setState: function(state) {
        this._state = state;
        if (!this._statusEl || !this._flashBtn) return;

        var labels = {
            'idle':     [_('Idle'),     '#6c757d'],
            'flashing': [_('Flashing'), '#fd7e14'],
            'completed':[_('Success'),  '#28a745'],
            'failed':   [_('Failed'),   '#dc3545'],
            'error':    [_('Error'),    '#dc3545']
        };
        var info = labels[state] || labels['idle'];
        this._statusEl.textContent = info[0];
        this._statusEl.style.color = info[1];

        var resetEl = document.getElementById('qf-reset-btn');

        if (state === 'flashing') {
            this._flashBtn.disabled = true;
            this._flashBtn.textContent = _('Flashing...');
            if (resetEl) resetEl.style.display = 'none';
        } else {
            this._flashBtn.disabled = false;
            this._flashBtn.textContent = _('Flash Firmware');
            if (resetEl && (state === 'completed' || state === 'failed' || state === 'error'))
                resetEl.style.display = '';
        }
    },

    getFormValue: function(id) {
        var el = document.getElementById('qf-' + id);
        if (!el) return '';
        if (el.type === 'checkbox') return el.checked ? '1' : '0';
        return el.value || '';
    },

    buildArgs: function() {
        var args = [];
        var firmware = this.getFormValue('firmware');
        if (firmware)
            args.push('-f', firmware);

        var port = this.getFormValue('port');
        if (port)
            args.push('-p', port);

        var device = this.getFormValue('device');
        if (device)
            args.push('-s', device);

        var deviceType = this.getFormValue('device_type');
        if (deviceType && deviceType !== 'nand')
            args.push('-d', deviceType);

        if (this.getFormValue('skip_md5') === '1')
            args.push('-n');

        if (this.getFormValue('erase_all') === '1')
            args.push('-e');

        if (this.getFormValue('signed_firmware') === '1')
            args.push('-v');

        if (this.getFormValue('capture_usbmon') === '1')
            args.push('-u', '/tmp/qfirehose_log/usbmon.log');

        return args;
    },

    handleFlashClick: function() {
        var firmware = this.getFormValue('firmware');
        if (!firmware) {
            ui.addNotification(null, E('p', _('Please select a firmware file first.')), 'warning');
            return;
        }

        if (this.getFormValue('erase_all') === '1') {
            return this.showEraseWarning();
        }

        this.showFlashWarning();
    },

    showEraseWarning: function() {
        var self = this;
        ui.showModal(_('Danger'), [
            E('div', { 'class': 'alert-message danger', 'style': 'border-left:4px solid #dc3545;padding:12px;background:#fff5f5;' }, [
                E('p', { 'style': 'font-weight:bold;color:#dc3545;' },
                    _('You have enabled "Erase All Before Download"!')),
                E('p', {},
                    _('This will erase ALL data on the modem, including calibration data. The modem may become permanently unusable if calibration data is lost.')),
                E('p', { 'style': 'font-weight:bold;' },
                    _('Are you absolutely sure you want to continue?'))
            ]),
            E('div', { 'class': 'right' }, [
                E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')),
                ' ',
                E('button', {
                    'class': 'btn cbi-button-negative',
                    'click': function() { ui.hideModal(); self.showFlashWarning(); }
                }, _('I understand the risk, continue'))
            ])
        ]);
    },

    showFlashWarning: function() {
        var self = this;
        var continueBtn = E('button', {
            'class': 'btn cbi-button-positive',
            'disabled': true
        }, _('Continue') + ' (10)');

        ui.showModal(_('Confirm Firmware Flash'), [
            E('div', { 'class': 'alert-message warning' }, [
                E('p', { 'style': 'font-weight:bold;' }, _('Please ensure before proceeding:')),
                E('ul', {}, [
                    E('li', {}, _('The firmware is from official channels and compatible with your modem.')),
                    E('li', {}, _('The firmware version should be higher than the current version.')),
                    E('li', {}, _('Flashing wrong firmware can brick your modem permanently.')),
                    E('li', {}, _('Do not flash if you are not willing to take this risk.'))
                ]),
                E('details', { 'style': 'margin-top:8px;' }, [
                    E('summary', { 'style': 'cursor:pointer;color:#6c757d;' }, _('Additional notes...')),
                    E('ul', { 'style': 'margin-top:6px;font-size:90%;color:#6c757d;' }, [
                        E('li', {}, _('After flashing, use AT&F command to factory reset modem settings.')),
                        E('li', {}, _('mPCIe users: If modem disappears after flashing, it may have switched to USB3 mode. Use mPCIe-to-USB adapter and send AT+QUSBCFG="SS",0 to switch back to USB2.'))
                    ])
                ])
            ]),
            E('div', { 'class': 'right' }, [
                E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')),
                ' ',
                continueBtn
            ])
        ]);

        var countdown = 10;
        var timer = setInterval(function() {
            countdown--;
            if (countdown > 0) {
                continueBtn.textContent = _('Continue') + ' (' + countdown + ')';
            } else {
                clearInterval(timer);
                continueBtn.textContent = _('Continue');
                continueBtn.disabled = false;
                continueBtn.onclick = function() {
                    ui.hideModal();
                    self.doFlash();
                };
            }
        }, 1000);
    },

    doFlash: function() {
        var args = this.buildArgs();
        this.setState('flashing');

        if (this._logEl) {
            this._logEl.value = _('Starting firmware flash process...') + '\n';
        }

        this.startLogPolling();

        var self = this;
        return fs.exec('/usr/sbin/qfirehose-start', args).catch(function(err) {
            self.setState('error');
            ui.addNotification(null, E('p', _('Failed to start flash process: ') + err.message), 'error');
        });
    },

    startLogPolling: function() {
        if (this._polling) return;
        this._polling = true;

        var self = this;
        this._pollFn = function() {
            return Promise.all([
                fs.exec('/usr/sbin/qfirehose-status'),
                fs.exec('cat', ['/tmp/qfirehose_log/current.log'])
            ]).then(function(results) {
                var statusRes = results[0];
                var logRes = results[1];

                // 更新日志
                if (self._logEl && logRes && logRes.stdout) {
                    self._logEl.value = logRes.stdout;
                    self._logEl.scrollTop = self._logEl.scrollHeight;
                }

                // 根据 qfirehose-status 返回的状态更新 UI
                var status = (statusRes && statusRes.stdout) ? statusRes.stdout.trim() : 'idle';
                if (status === 'completed') {
                    self.stopLogPolling();
                    self.setState('completed');
                    ui.addNotification(null, E('p', _('Firmware upgrade completed successfully!')), 'success');
                } else if (status === 'failed') {
                    self.stopLogPolling();
                    self.setState('failed');
                    ui.addNotification(null, E('p', _('Firmware upgrade failed.')), 'error');
                } else if (status === 'flashing') {
                    self.setState('flashing');
                } else {
                    self.stopLogPolling();
                    self.setState(status);
                }
            }).catch(function() {});
        };

        poll.add(this._pollFn, 2);
    },

    stopLogPolling: function() {
        if (this._polling && this._pollFn) {
            poll.remove(this._pollFn);
            this._polling = false;
            this._pollFn = null;
        }
    },

    createSelect: function(id, options, defaultVal) {
        var sel = E('select', {
            'id': 'qf-' + id,
            'class': 'cbi-input-select',
            'style': 'width:100%;'
        });
        options.forEach(function(opt) {
            var o = E('option', { 'value': opt[0] }, opt[1]);
            if (opt[0] === defaultVal) o.selected = true;
            sel.appendChild(o);
        });
        return sel;
    },

    createCheckbox: function(id, label, description, isDanger) {
        var cb = E('div', { 'class': 'cbi-value', 'style': 'padding:4px 0;' }, [
            E('label', { 'class': 'cbi-value-title', 'style': isDanger ? 'color:#dc3545;font-weight:bold;' : 'font-weight:bold;' }, label),
            E('div', { 'class': 'cbi-value-field' }, [
                E('label', { 'style': 'display:inline-flex;align-items:center;gap:6px;cursor:pointer;' }, [
                    E('input', {
                        'type': 'checkbox',
                        'id': 'qf-' + id,
                        'class': 'cbi-input-checkbox'
                    }),
                    description ? E('span', { 'style': 'font-size:85%;' + (isDanger ? 'color:#dc3545;' : '') }, description) : ''
                ])
            ])
        ]);
        return cb;
    },

    render: function(data) {
        var self = this;

        var version = '';
        if (data[0] && data[0].stdout) {
            var match = data[0].stdout.match(/Version:\s*([^\n]+)/);
            if (match) version = match[1].trim();
        }

        var ttyDevices = (data[1] || []).filter(function(dev) {
            return /^ttyUSB/.test(dev.name) || /^mhi_/.test(dev.name) || /^wwan/.test(dev.name);
        }).map(function(dev) { return dev.name; });

        var usbDevices = (data[2] || []).filter(function(dev) {
            return /^\d+-\d+/.test(dev.name);
        }).map(function(dev) { return dev.name; });

        var initStatus = 'idle';
        if (data[3] && data[3].stdout) {
            var st = data[3].stdout.trim();
            if (st === 'flashing' || st === 'completed' || st === 'failed') {
                initStatus = st;
            }
        }

        var modemModel = '', modemFirmware = '';
        if (data[5] && data[5].stdout) {
            var lines = data[5].stdout.split('\n');
            lines.forEach(function(line) {
                var kv = line.split('=');
                if (kv.length >= 2) {
                    var k = kv[0].trim(), v = kv.slice(1).join('=').trim();
                    if (k === 'model' && v !== 'N/A') modemModel = v;
                    if (k === 'firmware' && v !== 'N/A') modemFirmware = v;
                }
            });
        }

        var savedCfg = {
            port: uci.get('qfirehose', 'config', 'port') || '',
            device: uci.get('qfirehose', 'config', 'device') || '',
            device_type: uci.get('qfirehose', 'config', 'device_type') || 'nand',
            skip_md5: uci.get('qfirehose', 'config', 'skip_md5') || '0',
            erase_all: uci.get('qfirehose', 'config', 'erase_all') || '0',
            signed_firmware: uci.get('qfirehose', 'config', 'signed_firmware') || '0'
        };

        var statusEl = E('span', {
            'style': 'font-weight:bold;'
        }, _('Idle'));
        this._statusEl = statusEl;

        var portOpts = [['', _('Auto Detect')]];
        ttyDevices.forEach(function(d) { portOpts.push(['/dev/' + d, '/dev/' + d]); });

        var deviceOpts = [['', _('Auto Detect')]];
        usbDevices.forEach(function(d) { deviceOpts.push(['/sys/bus/usb/devices/' + d, d]); });

        var typeOpts = [
            ['nand', _('NAND (Default)')],
            ['emmc', _('eMMC')],
            ['ufs', _('UFS')]
        ];

        var firmwareInput = E('input', {
            'type': 'text',
            'id': 'qf-firmware',
            'class': 'cbi-input-text',
            'style': 'flex:1;',
            'placeholder': _('Upload firmware or enter path...')
        });

        var progressWrap = E('div', {
            'id': 'qf-progress-wrap',
            'style': 'display:none;margin-top:6px;'
        }, [
            E('div', { 'style': 'display:flex;align-items:center;gap:8px;' }, [
                E('div', {
                    'style': 'flex:1;height:6px;background:#e9ecef;border-radius:3px;overflow:hidden;'
                }, [
                    E('div', {
                        'id': 'qf-progress-bar',
                        'style': 'width:0%;height:100%;background:#28a745;border-radius:3px;transition:width 0.3s;'
                    })
                ]),
                E('span', {
                    'id': 'qf-progress-text',
                    'style': 'font-size:12px;color:#6c757d;min-width:40px;text-align:right;'
                }, '0%')
            ])
        ]);

        var fileInput = E('input', {
            'type': 'file',
            'style': 'display:none;',
            'change': function(ev) {
                var file = ev.target.files[0];
                if (!file) return;

                var path = '/tmp/qfirehoseupload/' + file.name;
                firmwareInput.value = path;

                var uploadBtn = document.getElementById('qf-upload-btn');
                var pWrap = document.getElementById('qf-progress-wrap');
                var pBar = document.getElementById('qf-progress-bar');
                var pText = document.getElementById('qf-progress-text');

                if (uploadBtn) {
                    uploadBtn.disabled = true;
                    uploadBtn.textContent = _('Uploading...');
                }
                if (pWrap) pWrap.style.display = '';
                if (pBar) pBar.style.width = '0%';
                if (pText) pText.textContent = '0%';

                var formData = new FormData();
                formData.append('sessionid', L.env.sessionid);
                formData.append('filename', path);
                formData.append('filedata', file);

                var xhr = new XMLHttpRequest();
                xhr.upload.onprogress = function(e) {
                    if (e.lengthComputable) {
                        var pct = Math.round(e.loaded / e.total * 100);
                        if (pBar) pBar.style.width = pct + '%';
                        if (pText) pText.textContent = pct + '%';
                    }
                };
                xhr.open('POST', L.env.cgi_base + '/cgi-upload');
                xhr.onload = function() {
                    if (uploadBtn) {
                        uploadBtn.disabled = false;
                        uploadBtn.textContent = _('Select File');
                    }
                    if (xhr.status === 200) {
                        if (pBar) pBar.style.background = '#28a745';
                        ui.addNotification(null, E('p', _('File uploaded successfully.')), 'info');
                    } else {
                        if (pBar) pBar.style.background = '#dc3545';
                        ui.addNotification(null, E('p', _('File upload failed.')), 'error');
                        firmwareInput.value = '';
                    }
                    setTimeout(function() { if (pWrap) pWrap.style.display = 'none'; }, 3000);
                };
                xhr.onerror = function() {
                    if (uploadBtn) {
                        uploadBtn.disabled = false;
                        uploadBtn.textContent = _('Select File');
                    }
                    if (pBar) pBar.style.background = '#dc3545';
                    if (pText) pText.textContent = _('Error');
                    ui.addNotification(null, E('p', _('File upload failed.')), 'error');
                    firmwareInput.value = '';
                    setTimeout(function() { if (pWrap) pWrap.style.display = 'none'; }, 3000);
                };
                xhr.send(formData);
            }
        });

        var advancedBody = E('div', {
            'id': 'qf-advanced-body',
            'style': 'display:none;'
        }, [
            E('div', { 'class': 'cbi-section-node' }, [
                this.createCheckbox('skip_md5', _('Skip MD5 Check'), _('Skip MD5 checksum verification'), false),
                this.createCheckbox('signed_firmware', _('Signed Firmware'), _('For AG215S-GLR signed firmware packages'), false),
                this.createCheckbox('capture_usbmon', _('Capture USBMon Log'), _('Capture USB monitor log for debugging (-u)'), false)
            ]),
            E('hr', { 'style': 'border:none;border-top:1px dashed #dc3545;margin:12px 0;opacity:0.5;' }),
            E('div', { 'class': 'cbi-section-node' }, [
                this.createCheckbox('erase_all', _('Erase All Before Download'),
                    _('Erase ALL data including calibration data — modem may become permanently unusable!'), true)
            ])
        ]);

        var advancedToggle = E('div', {
            'class': 'cbi-section-node',
            'style': 'display:flex;align-items:center;justify-content:space-between;padding:10px 16px;cursor:pointer;user-select:none;border:1px solid;border-color:inherit;border-radius:4px;',
            'click': function() {
                var body = document.getElementById('qf-advanced-body');
                var arrow = document.getElementById('qf-advanced-arrow');
                if (body.style.display === 'none') {
                    body.style.display = '';
                    arrow.textContent = '▼';
                } else {
                    body.style.display = 'none';
                    arrow.textContent = '▶';
                }
            }
        }, [
            E('strong', {}, _('Advanced Options')),
            E('span', { 'id': 'qf-advanced-arrow', 'style': 'font-size:12px;' }, '▶')
        ]);

        var flashBtn = E('button', {
            'class': 'btn cbi-button-positive',
            'style': 'font-size:16px;padding:10px 40px;',
            'click': ui.createHandlerFn(this, 'handleFlashClick')
        }, _('Flash Firmware'));
        this._flashBtn = flashBtn;

        var resetBtn = E('button', {
            'id': 'qf-reset-btn',
            'class': 'btn cbi-button',
            'style': 'font-size:14px;padding:8px 24px;display:none;',
            'click': ui.createHandlerFn(this, function() {
                this.stopLogPolling();
                this.setState('idle');
                if (this._logEl) this._logEl.value = '';
                var rb = document.getElementById('qf-reset-btn');
                if (rb) rb.style.display = 'none';
                fs.exec('rm', ['-f', '/tmp/qfirehose_log/status', '/tmp/qfirehose_log/pid']);
            })
        }, _('Reset'));

        var logEl = E('textarea', {
            'id': 'qfirehose-log',
            'readonly': 'readonly',
            'wrap': 'off',
            'rows': 20,
            'placeholder': _('Waiting for flash process to start...'),
            'style': 'width:100%;font-family:monospace;font-size:12px;white-space:pre;resize:vertical;background:#1e1e1e;color:#d4d4d4;border:1px solid #333;border-radius:4px;padding:8px;'
        }, '');
        this._logEl = logEl;

        var view = E('div', { 'class': 'cbi-map' }, [

            E('h2', {}, _('QFirehose')),
            E('div', { 'class': 'cbi-map-descr' },
                _('Qualcomm firmware flash tool for Quectel modems. Supports firmware directory, zip and 7z packages.')),

            E('div', { 'class': 'cbi-section' }, [
                E('div', { 'class': 'cbi-section-node' }, [
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('Modem Model')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            E('span', { 'id': 'qf-modem-model' }, modemModel || _('Not detected'))
                        ])
                    ]),
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('Current Firmware')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            E('span', { 'id': 'qf-modem-firmware' }, modemFirmware || _('Not detected'))
                        ])
                    ]),
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('Tool Version')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            E('span', {}, version || _('Unknown'))
                        ])
                    ]),
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('Status')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            statusEl
                        ])
                    ])
                ])
            ]),

            E('div', { 'class': 'cbi-section' }, [
                E('h3', {}, _('Firmware File')),
                E('div', { 'style': 'display:flex;gap:8px;align-items:center;' }, [
                    firmwareInput,
                    E('button', {
                        'id': 'qf-upload-btn',
                        'class': 'btn cbi-button-action',
                        'click': function() { fileInput.click(); }
                    }, _('Select File')),
                    fileInput
                ]),
                progressWrap,
                E('div', { 'style': 'font-size:90%;color:#6c757d;margin-top:4px;' },
                    _('Supports .zip, .7z packages and firmware directories'))
            ]),

            E('div', { 'class': 'cbi-section' }, [
                E('div', { 'style': 'display:flex;align-items:center;justify-content:space-between;' }, [
                    E('h3', { 'style': 'margin:0;' }, _('Device Settings')),
                    E('button', {
                        'class': 'btn cbi-button',
                        'style': 'font-size:12px;padding:2px 10px;',
                        'click': function(ev) {
                            var btn = ev.target;
                            btn.disabled = true;
                            btn.textContent = _('Refreshing...');
                            Promise.all([
                                fs.list('/dev'),
                                fs.list('/sys/bus/usb/devices'),
                                L.resolveDefault(fs.exec('/usr/sbin/qfirehose-modem-info'), {})
                            ]).then(function(results) {
                                var newTty = (results[0] || []).filter(function(dev) {
                                    return /^ttyUSB/.test(dev.name) || /^mhi_/.test(dev.name) || /^wwan/.test(dev.name);
                                }).map(function(dev) { return dev.name; });
                                var newUsb = (results[1] || []).filter(function(dev) {
                                    return /^\d+-\d+/.test(dev.name);
                                }).map(function(dev) { return dev.name; });

                                var portSel = document.getElementById('qf-port');
                                var devSel = document.getElementById('qf-device');
                                if (portSel) {
                                    var curPort = portSel.value;
                                    portSel.innerHTML = '';
                                    portSel.appendChild(E('option', { 'value': '' }, _('Auto Detect')));
                                    newTty.forEach(function(d) {
                                        var o = E('option', { 'value': '/dev/' + d }, '/dev/' + d);
                                        if ('/dev/' + d === curPort) o.selected = true;
                                        portSel.appendChild(o);
                                    });
                                }
                                if (devSel) {
                                    var curDev = devSel.value;
                                    devSel.innerHTML = '';
                                    devSel.appendChild(E('option', { 'value': '' }, _('Auto Detect')));
                                    newUsb.forEach(function(d) {
                                        var o = E('option', { 'value': '/sys/bus/usb/devices/' + d }, d);
                                        if ('/sys/bus/usb/devices/' + d === curDev) o.selected = true;
                                        devSel.appendChild(o);
                                    });
                                }

                                var modemInfo = results[2];
                                if (modemInfo && modemInfo.stdout) {
                                    var modelEl = document.getElementById('qf-modem-model');
                                    var fwEl = document.getElementById('qf-modem-firmware');
                                    modemInfo.stdout.split('\n').forEach(function(line) {
                                        var kv = line.split('=');
                                        if (kv.length >= 2) {
                                            var k = kv[0].trim(), v = kv.slice(1).join('=').trim();
                                            if (k === 'model' && modelEl) modelEl.textContent = (v && v !== 'N/A') ? v : _('Not detected');
                                            if (k === 'firmware' && fwEl) fwEl.textContent = (v && v !== 'N/A') ? v : _('Not detected');
                                        }
                                    });
                                }

                                btn.disabled = false;
                                btn.textContent = _('Refresh Devices');
                            }).catch(function() {
                                btn.disabled = false;
                                btn.textContent = _('Refresh Devices');
                            });
                        }
                    }, _('Refresh Devices'))
                ]),
                E('div', { 'class': 'cbi-section-node' }, [
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('Communication Port')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            this.createSelect('port', portOpts, savedCfg.port)
                        ])
                    ]),
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('USB Device')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            this.createSelect('device', deviceOpts, savedCfg.device)
                        ])
                    ]),
                    E('div', { 'class': 'cbi-value' }, [
                        E('label', { 'class': 'cbi-value-title' }, _('Device Type')),
                        E('div', { 'class': 'cbi-value-field' }, [
                            this.createSelect('device_type', typeOpts, savedCfg.device_type)
                        ])
                    ])
                ])
            ]),

            E('div', { 'class': 'cbi-section', 'style': 'padding:0;' }, [
                advancedToggle,
                advancedBody
            ]),

            E('div', {
                'class': 'cbi-section',
                'style': 'text-align:center;padding:16px;display:flex;justify-content:center;gap:12px;align-items:center;'
            }, [flashBtn, resetBtn]),

            E('div', { 'class': 'cbi-section' }, [
                E('div', { 'style': 'display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;' }, [
                    E('h3', { 'style': 'margin:0;' }, _('Flash Log')),
                    E('div', { 'style': 'display:flex;gap:6px;' }, [
                        E('button', {
                            'class': 'btn cbi-button-action',
                            'style': 'font-size:12px;padding:2px 10px;',
                            'click': function() {
                                var log = document.getElementById('qfirehose-log');
                                if (log && log.value) {
                                    navigator.clipboard.writeText(log.value).then(function() {
                                        ui.addNotification(null, E('p', _('Log copied to clipboard.')), 'info');
                                    });
                                }
                            }
                        }, _('Copy')),
                        E('button', {
                            'class': 'btn cbi-button-reset',
                            'style': 'font-size:12px;padding:2px 10px;',
                            'click': function() {
                                var log = document.getElementById('qfirehose-log');
                                if (log) log.value = '';
                            }
                        }, _('Clear'))
                    ])
                ]),
                logEl
            ])
        ]);

        if (savedCfg.skip_md5 === '1')
            document.getElementById && setTimeout(function() {
                var el = document.getElementById('qf-skip_md5');
                if (el) el.checked = true;
            }, 0);
        if (savedCfg.erase_all === '1')
            setTimeout(function() {
                var el = document.getElementById('qf-erase_all');
                if (el) el.checked = true;
            }, 0);
        if (savedCfg.signed_firmware === '1')
            setTimeout(function() {
                var el = document.getElementById('qf-signed_firmware');
                if (el) el.checked = true;
            }, 0);

        if (initStatus === 'flashing') {
            setTimeout(function() {
                self.setState('flashing');
                self.startLogPolling();
            }, 100);
        }

        return view;
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
