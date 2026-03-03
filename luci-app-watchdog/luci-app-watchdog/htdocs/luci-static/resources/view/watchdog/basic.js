/*   Copyright (C) 2025 sirpdboy herboy2008@gmail.com https://github.com/sirpdboy/luci-app-watchdog */

'use strict';
'require view';
'require fs';
'require ui';
'require uci';
'require form';
'require poll';

function checkProcess() {
    return fs.exec('/bin/pidof', ['watchdog']).then(function(res) {
        return {
            running: res.code === 0,
            pid: res.code === 0 ? res.stdout.trim() : null
        };
    }).catch(function() {
        return { running: false, pid: null };
    });
}

function renderStatus(isRunning) {
    var statusText = isRunning ? _('RUNNING') : _('NOT RUNNING');
    var color = isRunning ? 'green' : 'red';
    var icon = isRunning ? '✓' : '✗'; 
    
    return String.format(
        '<em><span style="color:%s">%s <strong>%s %s</strong></span></em>',
        color, icon, _('watchdog'), statusText
    );
}

var cbiRichListValue = form.ListValue.extend({
    renderWidget: function (section_id, option_index, cfgvalue) {
        var choices = this.transformChoices();
        var widget = new ui.Dropdown((cfgvalue != null) ? cfgvalue : this.default, choices, {
            id: this.cbid(section_id),
            sort: this.keylist,
            optional: true,
            select_placeholder: this.select_placeholder || this.placeholder,
            custom_placeholder: this.custom_placeholder || this.placeholder,
            validate: L.bind(this.validate, this, section_id),
            disabled: (this.readonly != null) ? this.readonly : this.map.readonly
        });

        return widget.render();
    },

    value: function (value, title, description) {
        if (description) {
            form.ListValue.prototype.value.call(this, value, E([], [
                E('span', { 'class': 'hide-open' }, [title]),
                E('div', { 'class': 'hide-close', 'style': 'min-width:25vw' }, [
                    E('strong', [title]),
                    E('br'),
                    E('span', { 'style': 'white-space:normal' }, description)
                ])
            ]));
        }
        else {
            form.ListValue.prototype.value.call(this, value, title);
        }
    }
});

return view.extend({

    render: function() {

        var m, s, o;
        m = new form.Map('watchdog', _('watchdog'), _('This is the security watchdog plugin for OpenWRT, which monitors and guards web login, SSH connections, and other situations.<br /><br />If you encounter any issues while using it, please submit them here:') + '<a href="https://github.com/sirpdboy/luci-app-watchdog" target="_blank">' + _('GitHub Project Address') + '</a>');
        
        s = m.section(form.TypedSection);
        s.anonymous = true;
        s.render = function() {
            var statusView = E('p', { id: 'control_status' }, 
                '<span class="spinning"> </span> ' + _('Checking status...'));
            
            poll.add(function() {
                return checkProcess()
                    .then(function(res) {
                        var status = renderStatus(res.running);
                        if (res.running && res.pid) {
                            status += ' <small>(PID: ' + res.pid + ')</small>';
                        }
                        statusView.innerHTML = status;
                    })
                    .catch(function(err) {
                        statusView.innerHTML = '<span style="color:orange">⚠ ' + 
                            _('Status check failed') + '</span>';
                        console.error('Status check error:', err);
                    });
            });

            poll.start();
            return E('div', { class: 'cbi-section', id: 'status_bar' }, [ statusView ,
               E('div', { 'style': 'text-align: right; font-style: italic;' }, [
                    E('span', {}, [
                    _('© github '),
                    E('a', { 
                        'href': 'https://github.com/sirpdboy', 
                        'target': '_blank',
                        'style': 'text-decoration: none;'
                    }, 'by sirpdboy')
                ])
            ])
        ]);
        }

        s = m.section(form.NamedSection, 'config', 'watchdog', _(''));
        s.tab('basic', _('Basic Settings'));
        s.tab('blacklist', _('Black list'));
        s.addremove = false;
        s.anonymous = true;

        o = s.taboption('basic', form.Flag, 'enable', _('Enabled'));
        
        o = s.taboption('basic', form.Value, 'sleeptime', _('Check Interval (s)'));
        o.rmempty = false;
        o.placeholder = '60';
        o.datatype = 'and(uinteger,min(10))';
        o.description = _('Shorter intervals provide quicker response but consume more system resources.');

        o = s.taboption('basic', form.MultiValue, 'login_control', _('Login control'));
        o.value('web_logged', _('Web Login'));
        o.value('ssh_logged', _('SSH Login'));
        o.value('web_login_failed', _('Frequent Web Login Errors'));
        o.value('ssh_login_failed', _('Frequent SSH Login Errors'));
        o.modalonly = true;

        o = s.taboption('basic', form.Value, 'login_max_num', _('Login failure count'));
        o.default = '3';
        o.rmempty = false;
        o.datatype = 'and(uinteger,min(1))';
        o.depends({ login_control: "web_login_failed", '!contains': true });
        o.depends({ login_control: "ssh_login_failed", '!contains': true });
        o.description = _('Reminder and optional automatic IP ban after exceeding the number of times');

        o = s.taboption('blacklist', form.Flag, 'login_web_black', _('Auto-ban unauthorized login devices'));
        o.default = '0';
        o.depends({ login_control: "web_login_failed", '!contains': true });
        o.depends({ login_control: "ssh_login_failed", '!contains': true });
        
        o = s.taboption('blacklist', form.Value, 'login_ip_black_timeout', _('Blacklisting time (s)'));
        o.default = '86400';
        o.rmempty = false;
        o.datatype = 'and(uinteger,min(0))';
        o.depends('login_web_black', '1');
        o.description = _('\"0\" in ipset means permanent blacklist, use with caution. If misconfigured, change the device IP and clear rules in LUCI.');

        o = s.taboption('blacklist', form.TextValue, 'ip_black_list', _('IP blacklist'));
        o.rows = 8;
        o.wrap = 'soft';
        
        // 修复：正确处理空文件的情况
        o.cfgvalue = function(section_id) {
            return fs.read('/usr/share/watchdog/api/ip_blacklist')
                .then(function(content) {
                    // 如果文件不存在或为空，返回空字符串
                    return content || '';
                })
                .catch(function(err) {
                    console.error('Failed to read blacklist:', err);
                    return '';
                });
        };
        
        // 修复：确保空值能被正确保存，并触发日志
        o.write = function(section_id, formvalue) {
            var self = this;
            
            return self.cfgvalue(section_id).then(function(oldValue) {
                // 处理空值 - 如果表单值为空或只包含空白字符，清空文件
                var newValue = (formvalue || '').trim();
                
                // 如果值没有变化，不执行写入
                if (oldValue === newValue) {
                    return;
                }
                
                // 处理空值情况 - 清空文件
                if (newValue === '') {
                    return fs.write('/usr/share/watchdog/api/ip_blacklist', '')
                        .then(function() {
                            // 添加成功通知
                            ui.addNotification(null, E('p', {}, _('Blacklist cleared successfully')));
                            
                            // 触发 watchdog 重新加载配置，这会记录日志
                            return fs.exec('/etc/init.d/watchdog', ['restart'])
                                .then(function() {
                                    console.log('Watchdog restarted successfully');
                                })
                                .catch(function(err) {
                                    console.error('Failed to restart watchdog:', err);
                                    // 即使重启失败，也尝试手动触发清理
                                    return fs.exec('/usr/bin/logger', ['-t', 'watchdog', 'Blacklist cleared via web interface']);
                                });
                        });
                }
                
                // 格式化内容：每行一个IP，去除空行
                var lines = newValue.split('\n');
                var validLines = [];
                
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    // 跳过空行
                    if (line === '') {
                        continue;
                    }
                    validLines.push(line);
                }
                
                // 如果没有有效IP，清空文件
                if (validLines.length === 0) {
                    return fs.write('/usr/share/watchdog/api/ip_blacklist', '')
                        .then(function() {
                            ui.addNotification(null, E('p', {}, _('Blacklist cleared successfully')));
                            
                            // 触发 watchdog 重新加载配置
                            return fs.exec('/etc/init.d/watchdog', ['restart'])
                                .then(function() {
                                    console.log('Watchdog restarted successfully');
                                })
                                .catch(function(err) {
                                    console.error('Failed to restart watchdog:', err);
                                    return fs.exec('/usr/bin/logger', ['-t', 'watchdog', 'Blacklist cleared via web interface']);
                                });
                        });
                }
                
                // 找出删除的IP（对比新旧内容）
                var oldLines = oldValue ? oldValue.split('\n').map(function(line) { return line.trim(); }).filter(function(line) { return line !== ''; }) : [];
                var removedIPs = oldLines.filter(function(ip) {
                    return validLines.indexOf(ip) === -1;
                });
                
                // 写入格式化的内容，每个IP一行
                var content = validLines.join('\n') + '\n';
                return fs.write('/usr/share/watchdog/api/ip_blacklist', content)
                    .then(function() {
                        var message = _('Blacklist updated successfully');
                        if (removedIPs.length > 0) {
                            message += ' ' + _('Removed %s IP(s)').replace('%s', removedIPs.length);
                            // 记录到系统日志
                            return fs.exec('/usr/bin/logger', ['-t', 'watchdog', 'Removed IPs from blacklist: ' + removedIPs.join(', ')])
                                .then(function() {
                                    ui.addNotification(null, E('p', {}, message));
                                    return fs.exec('/etc/init.d/watchdog', ['restart']);
                                });
                        } else {
                            ui.addNotification(null, E('p', {}, message));
                            return fs.exec('/etc/init.d/watchdog', ['restart']);
                        }
                    })
                    .catch(function(err) {
                        ui.addNotification(null, E('p', { style: 'color:red' }, 
                            _('Failed to update blacklist: ') + err.message));
                        return Promise.reject(err);
                    });
            }).catch(function(err) {
                ui.addNotification(null, E('p', { style: 'color:red' }, 
                    _('Failed to read current blacklist: ') + err.message));
                return Promise.reject(err);
            });
        };
        
        o.description = _('Automatic ban blacklist list, with the ban time following the IP address. Delete all entries to clear the blacklist.');

        return m.render();
    }
});