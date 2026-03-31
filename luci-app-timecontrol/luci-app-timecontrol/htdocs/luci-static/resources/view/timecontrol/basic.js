// SPDX-License-Identifier: Apache-2.0
/*

 * Copyright (C) 2022-2026 sirpdboy <herboy2008@gmail.com>
 */
'use strict';
'require view';
'require fs';
'require ui';
'require uci';
'require form';
'require poll';
'require rpc';
'require network';

function checkTimeControlProcess() {
    return fs.exec('/bin/ps', ['w']).then(function(res) {
        if (res.code !== 0) {
            return { running: false, pid: null };
        }
        
        var lines = res.stdout.split('\n');
        var running = false;
        var pid = null;
        
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.includes('timecontrolctrl')) {
                running = true;
                // 提取PID
                var match = line.match(/^\s*(\d+)/);
                if (match) {
                    pid = match[1];
                }
                break;
            }
        }
        
        return { running: running, pid: null };
    }).catch(function() {
        return { running: false, pid: null };
    });
}

function renderServiceStatus(isRunning, pid) {
    var statusText = isRunning ? _('RUNNING') : _('NOT RUNNING');
    var color = isRunning ? 'green' : 'red';
    var icon = isRunning ? '✓' : '✗'; 
    
    var statusHtml = String.format(
        '<em><span style="color:%s">%s <strong>%s %s</strong></span></em>',
        color, icon, _('TimeControl Service'), statusText
    );
    
    if (isRunning && pid) {
        statusHtml += ' <small>(PID: ' + pid + ')</small>';
    }
    
    return statusHtml;
}

function getHostList() {
    return L.resolveDefault(network.getHostHints(), [])
        .then(function(hosts) {
            var hostList = [];
            if (hosts && hosts.length > 0) {
                hosts.forEach(function(host) {
                    if (host.ipv4 && host.mac) {
                        hostList.push({
                            ipv4: host.ipv4,
                            mac: host.mac,
                            name: host.name || '',
                            ipv6: host.ipv6 || ''
                        });
                    }
                });
            }
            return hostList;
        })
        .catch(function() {
            return [];
        });
}

var cbiRichListValue = form.ListValue.extend({
    renderWidget: function(section_id, option_index, cfgvalue) {
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

    value: function(value, title, description) {
        if (description) {
            form.ListValue.prototype.value.call(this, value, E([], [
                E('span', { 'class': 'hide-open' }, [title]),
                E('div', { 'class': 'hide-close', 'style': 'min-width:25vw' }, [
                    E('strong', [title]),
                    E('br'),
                    E('span', { 'style': 'white-space:normal' }, description)
                ])
            ]));
        } else {
            form.ListValue.prototype.value.call(this, value, title);
        }
    }
});

return view.extend({
    load: function() {
        return Promise.all([
            uci.load('timecontrol'),
            network.getHostHints()
        ]);
    },

    render: function(data) {
        var m, s, o;
        let hosts = data[1]?.hosts;

        m = new form.Map('timecontrol', _('Internet Time Control'),
            _('Users can limit their internet usage time through MAC and IP, with available IP ranges such as 192.168.110.00 to 192.168.10.200') + '<br/>' +
            _('黑名单模式时间控制方式:') + '<br/>' +
            _('1. 时间段控制: 指定的机器在设定时间段内可以上网，其他时间不能上网') + '<br/>' +
            _('2. 允许上机时长: 指定的机器上线后可以上网指定时长，超过时长后不能上网') + '<br/>' +
            _('3. 组合控制: 在时间段内+时长限制（在允许的时间段内限制上网时长）') + '<br/>' +
            _('Suggested feedback:') + ' <a href="https://github.com/sirpdboy/luci-app-timecontrol.git" target="_blank">GitHub @timecontrol</a>');

        s = m.section(form.TypedSection);
        s.anonymous = true;
        s.render = function() {
            var statusView = E('p', { id: 'service_status' }, 
                '<span class="spinning"> </span> ' + _('Checking service status...'));
            
            checkTimeControlProcess()
                .then(function(res) {
                    var status = renderServiceStatus(res.running, res.pid);
                    statusView.innerHTML = status;
                })
                .catch(function(err) {
                    statusView.innerHTML = '<span style="color:orange">⚠ ' + 
                        _('Status check failed') + '</span>';
                    console.error('Status check error:', err);
                });
            
            poll.add(function() {
                return checkTimeControlProcess()
                    .then(function(res) {
                        var status = renderServiceStatus(res.running, res.pid);
                        statusView.innerHTML = status;
                    })
                    .catch(function(err) {
                        statusView.innerHTML = '<span style="color:orange">⚠ ' + 
                            _('Status check failed') + '</span>';
                        console.error('Status check error:', err);
                    });
            }, 5); 

            poll.start();
            return E('div', { class: 'cbi-section', id: 'status_bar' }, [ 
                statusView,
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
        };
        s = m.section(form.TypedSection, 'timecontrol');
        s.anonymous = true;
        s.addremove = false;

        o = s.option(cbiRichListValue, 'list_type', _('Control Mode'),
            _('blacklist: Block the networking of the target address, whitelist: Only allow networking for the target address and block all other addresses.'));
        o.rmempty = false;
        o.value('blacklist', _('Blacklist'));
        // o.value('whitelist', _('Whitelist'));
        o.default = 'blacklist';

        o = s.option(cbiRichListValue, 'chain', _('Control Intensity'),
            _('Pay attention to strong control: machines under control will not be able to connect to the software router backend!'));
        o.value('forward', _('Ordinary forward control'));
        o.value('input', _('Strong input control'));
        o.default = 'forward';
        o.rmempty = false;

        var s = m.section(form.TableSection, 'device',  _('Device Rules'));
        s.addremove = true;
        s.anonymous = true;
        s.sortable = false;

        o = s.option(form.Value, 'comment', _('Comment'));
        o.optional = true;
        o.placeholder = _('Description');

        o = s.option(form.Flag, 'enable', _('Enabled'));
        o.rmempty = false;
        o.default = '1';
        
        o = s.option(form.Value, 'mac', _('IP/MAC Address'));
        o.rmempty = false;
        if (hosts) {
            var hostOptions = {};
            
            Object.keys(hosts).forEach(function(mac) {
                var host = hosts[mac];
                var name = host.name || _(' ');
                var ips = L.toArray(host.ipaddrs || host.ipv4 || []);

                if (ips.length > 0) {
                    ips.forEach(function(ip) {
                        var macDisplay = 'MAC: %s (%s - %s)'.format(mac,ip, name);
                        hostOptions['mac:' + mac] = macDisplay;
                        var ipDisplay = 'IP: %s (%s - %s)'.format(ip, mac, name);
                        hostOptions['ip:' + ip] = ipDisplay;
                    });
                }
            });
            var sortedKeys = Object.keys(hostOptions).sort(function(a, b) {
                return hostOptions[a].localeCompare(hostOptions[b]);
            });
            
            sortedKeys.forEach(function(key) {
                if (key.startsWith('ip:')) {
                    o.value(key.substring(3), hostOptions[key]);
                }
            });

            sortedKeys.forEach(function(key) {
                if (key.startsWith('mac:')) {
                    o.value(key.substring(4), hostOptions[key]);
                }
            });
        }

        // 时间控制方式选择
        o = s.option(cbiRichListValue, 'time_mode', _('Time Control Mode'));
        o.value('period', _('Time Period Control (allow in period)'));
        o.value('duration', _('Allow Duration Control (allow limited time)'));
        o.value('combined', _('Combined Control (allow in period + limit duration)'));
        o.default = 'period';
        o.rmempty = false;
        o.onchange = function(ev, mode) {
            var row = this.map.findElement('id', this.cbid(this.section_id));
            if (row) {
                // 显示/隐藏相关字段
                var startTime = row.querySelector('[data-field="timestart"]');
                var endTime = row.querySelector('[data-field="timeend"]');
                var duration = row.querySelector('[data-field="duration"]');
                var useDuration = row.querySelector('[data-field="use_duration"]');
                var resetCycle = row.querySelector('[data-field="reset_cycle"]');
                
                if (startTime) startTime.parentElement.style.display = 
                    (mode === 'period' || mode === 'combined') ? '' : 'none';
                if (endTime) endTime.parentElement.style.display = 
                    (mode === 'period' || mode === 'combined') ? '' : 'none';
                if (duration) duration.parentElement.style.display = 
                    (mode === 'duration' || mode === 'combined') ? '' : 'none';
                if (useDuration) useDuration.parentElement.style.display = 
                    (mode === 'combined') ? '' : 'none';
                if (resetCycle) resetCycle.parentElement.style.display = 
                    (mode === 'duration' || mode === 'combined') ? '' : 'none';
            }
        };

        // 时间段控制字段
        o = s.option(form.Value, 'timestart', _('Allow Start Time'));
        o.placeholder = '00:00';
        o.default = '00:00';
        o.depends({ 'time_mode': 'period', '!contains': true });
        o.depends({ 'time_mode': 'combined', '!contains': true });

        o = s.option(form.Value, 'timeend', _('Allow End Time'));
        o.placeholder = '00:00';
        o.default = '00:00';
        o.depends({ 'time_mode': 'period', '!contains': true });
        o.depends({ 'time_mode': 'combined', '!contains': true });

        // 持续时间控制字段
        o = s.option(form.Value, 'duration', _('Allowed Duration (minutes)'));
        o.placeholder = '60';
        o.default = '60';
        o.datatype = 'min(1)';
        o.depends({ 'time_mode': 'duration', '!contains': true });
        o.depends({ 'time_mode': 'combined', '!contains': true });
        o.description = _('设备上线后允许上网的分钟数，超过后将被禁止上网');

        // 重置周期
        o = s.option(cbiRichListValue, 'reset_cycle', _('Reset Cycle'));
        o.value('daily', _('Daily Reset'));
        o.value('weekly', _('Weekly Reset'));
        o.value('monthly', _('Monthly Reset'));
        o.value('never', _('Never Reset (until manual reset)'));
        o.default = 'daily';
        o.depends({ 'time_mode': 'duration', '!contains': true });
        o.depends({ 'time_mode': 'combined', '!contains': true });
        o.description = _('时长重置周期');

        // 组合控制：是否在时间段内启用时长限制
        o = s.option(form.Flag, 'use_duration', _('Enable Duration Limit in Period'));
        o.default = '0';
        o.depends({ 'time_mode': 'combined', '!contains': true });
        o.description = _('在允许的时间段内限制上网时长');

        o = s.option(form.Value, 'week', _('Week Day (1~7)'));
        o.value('0', _('Everyday'));
        o.value('1', _('Monday'));
        o.value('2', _('Tuesday'));
        o.value('3', _('Wednesday'));
        o.value('4', _('Thursday'));
        o.value('5', _('Friday'));
        o.value('6', _('Saturday'));
        o.value('7', _('Sunday'));
        o.value('1,2,3,4,5', _('Workday'));
        o.value('6,7', _('Rest Day'));
        o.default = '0';
        o.rmempty = false;
        o.description = _('允许上网的星期');

        return m.render();
    }
});