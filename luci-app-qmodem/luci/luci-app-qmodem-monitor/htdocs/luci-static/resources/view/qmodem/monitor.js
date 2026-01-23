'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require ui';
'require poll';

var callInitAction = rpc.declare({
	object: 'luci',
	method: 'setInitAction',
	params: ['name', 'action'],
	expect: { result: false }
});

var callRcStatus = rpc.declare({
	object: 'rc',
	method: 'list',
	params: ['name'],
	expect: { }
});

// Monitor method definitions with their specific parameters
var monitorMethods = {
	'ping': {
		name: 'Ping',
		description: 'Ping target to check connectivity',
		params: {
			'monitor_ping_type': {
				title: 'Ping Type',
				type: 'select',
				values: {
					'ip': 'IP Address / Domain',
					'gateway': 'Gateway',
					'dns': 'DNS Server'
				},
				default: 'gateway'
			},
			'monitor_ping_dest': {
				title: 'Target IP / Domain',
				type: 'string',
				placeholder: '8.8.8.8'
			},
			'monitor_ping_ip_version': {
				title: 'IP Version',
				type: 'select',
				values: { '4': 'IPv4', '6': 'IPv6' },
				default: '4'
			}
		}
	},
	'curl': {
		name: 'HTTP Request',
		description: 'HTTP request to check connectivity',
		params: {
			'monitor_http_url': {
				title: 'URL',
				type: 'string',
				placeholder: 'http://www.example.com',
				default: 'http://www.baidu.com'
			}
		}
	}
};

// Action definitions with their specific parameters
var actionTypes = {
	'switch_sim_slot': {
		name: 'Switch SIM Slot',
		description: 'Switch to another SIM slot',
		params: {}
	},
	'send_at_commands': {
		name: 'Send AT Commands',
		description: 'Send AT commands to modem',
		params: {
			'at_command': {
				title: 'AT Commands',
				type: 'list',
				placeholder: 'AT+CFUN=1,1'
			}
		}
	},
	'run_scripts': {
		name: 'Run Scripts',
		description: 'Run custom scripts',
		params: {
			'script': {
				title: 'Script Paths',
				type: 'list',
				placeholder: '/usr/bin/my_script.sh'
			}
		}
	}
};

return view.extend({
	load: function() {
		var self = this;
		return Promise.all([
			uci.load('qmodem'),
			callRcStatus('qmodem_monitor')
		]).then(function(results) {
			self.rcStatusData = results[1];
			return results;
		});
	},

	render: function() {
		var m, s, o;
		var self = this;

		m = new form.Map('qmodem', _('QModem Monitor Configuration'),
			_('Configure monitoring methods and actions for modem connectivity.'));

		// Global Monitor Configuration
		s = m.section(form.NamedSection, 'main', 'main', _('Global Monitor Settings'));
		s.anonymous = true;


		// QModem Monitor RC status display
		var rcStatus = s.option(form.DummyValue, '_rc_status', _('Monitor Service'));
		rcStatus.rawhtml = true;
		rcStatus.cfgvalue = L.bind(function() {
			var status = this.rcStatusData && this.rcStatusData.qmodem_monitor ? this.rcStatusData.qmodem_monitor : null;
			
			if (!status) {
				return E('div', { id: 'rc-status-container' }, [
					E('span', {}, _('Failed to load status'))
				]);
			}
			
			var enabled = status.enabled === true || status.enabled === 'true';
			var running = status.running === true || status.running === 'true';
			
			return E('div', { id: 'rc-status-container' }, [
				E('span', {}, _('Enabled') + ': ' + (enabled ? _('Yes') : _('No'))),
				E('span', { 'style': 'margin-left: 12px;' }, _('Running') + ': ' + (running ? _('Yes') : _('No')))
			]);
		}, this);

		// Service Control buttons
		var rcControl = s.option(form.DummyValue, '_monitor_control', _('Service Control'));
		rcControl.rawhtml = true;
		rcControl.cfgvalue = L.bind(function() {
			var status = this.rcStatusData && this.rcStatusData.qmodem_monitor ? this.rcStatusData.qmodem_monitor : null;
			var enabled = status ? (status.enabled === true || status.enabled === 'true') : false;
			var running = status ? (status.running === true || status.running === 'true') : false;
			
			var buttons = [];
			
			// Running control: show Start if not running, show Stop and Restart if running
			if (!running) {
				buttons.push(
					E('button', {
						'class': 'cbi-button cbi-button-action',
						'id': 'rc-start-button',
						'click': ui.createHandlerFn(this, function() {
							var self = this;
							return callInitAction('qmodem_monitor', 'start')
								.then(function() {
									ui.addNotification(null, E('p', _('Monitor service started successfully')));
									return self.updateRcStatus();
								})
								.catch(function(err) {
									ui.addNotification(null, E('p', _('Failed to start monitor: ') + err.message), 'error');
									return self.updateRcStatus();
								});
						})
					}, _('Start'))
				);
			} else {
				buttons.push(
					E('button', {
						'class': 'cbi-button cbi-button-reset',
						'id': 'rc-stop-button',
						'click': ui.createHandlerFn(this, function() {
							var self = this;
							return callInitAction('qmodem_monitor', 'stop')
								.then(function() {
									ui.addNotification(null, E('p', _('Monitor service stopped successfully')));
									return self.updateRcStatus();
								})
								.catch(function(err) {
									ui.addNotification(null, E('p', _('Failed to stop monitor: ') + err.message), 'error');
									return self.updateRcStatus();
								});
						})
					}, _('Stop'))
				);
				buttons.push(
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						'id': 'rc-restart-button',
						'style': 'margin-left: 8px;',
						'click': ui.createHandlerFn(this, function() {
							var self = this;
							return callInitAction('qmodem_monitor', 'restart')
								.then(function() {
									ui.addNotification(null, E('p', _('Monitor service restarted successfully')));
									return self.updateRcStatus();
								})
								.catch(function(err) {
									ui.addNotification(null, E('p', _('Failed to restart monitor: ') + err.message), 'error');
									return self.updateRcStatus();
								});
						})
					}, _('Restart'))
				);
			}
			
			buttons.push(E('span', { 'style': 'margin: 0 8px;' }, ' | '));

			// Enabled control: show Enable if not enabled, show Disable if enabled
			if (!enabled) {
				buttons.push(
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						'id': 'rc-enable-button',
						'click': ui.createHandlerFn(this, function() {
							var self = this;
							return callInitAction('qmodem_monitor', 'enable')
								.then(function() {
									ui.addNotification(null, E('p', _('Monitor service enabled successfully')));
									return self.updateRcStatus();
								})
								.catch(function(err) {
									ui.addNotification(null, E('p', _('Failed to enable monitor: ') + err.message), 'error');
									return self.updateRcStatus();
								});
						})
					}, _('Enable'))
				);
			} else {
				buttons.push(
					E('button', {
						'class': 'cbi-button cbi-button-negative',
						'id': 'rc-disable-button',
						'click': ui.createHandlerFn(this, function() {
							var self = this;
							return callInitAction('qmodem_monitor', 'disable')
								.then(function() {
									ui.addNotification(null, E('p', _('Monitor service disabled successfully')));
									return self.updateRcStatus();
								})
								.catch(function(err) {
									ui.addNotification(null, E('p', _('Failed to disable monitor: ') + err.message), 'error');
									return self.updateRcStatus();
								});
						})
					}, _('Disable'))
				);
			}
			
			return E('div', { id: 'rc-control-container' }, buttons);
		}, this);

		// Per-Modem Monitor Configuration
		s = m.section(form.GridSection, 'modem-device', _('Modem Monitor Configuration'));
		s.anonymous = false;
		s.addremove = false;
		s.modaltitle = function(section_id) {
			var name = uci.get('qmodem', section_id, 'name');
			var alias = uci.get('qmodem', section_id, 'alias');
			return _('Monitor Configuration') + ': ' + (alias || name || section_id);
		};

		// Grid columns
		o = s.option(form.DummyValue, 'name', _('Modem'));
		o.cfgvalue = function(section_id) {
			var name = uci.get('qmodem', section_id, 'name') || '';
			var alias = uci.get('qmodem', section_id, 'alias');
			return alias ? alias + ' (' + name + ')' : name;
		};

		o = s.option(form.Flag, 'monitor_enabled', _('Enable'));
		o.default = '0';
		o.rmempty = false;
		o.editable = true;

		o = s.option(form.DummyValue, '_monitor_method_display', _('Method'));
		o.cfgvalue = function(section_id) {
			var method = uci.get('qmodem', section_id, 'monitor_method');
			if (method && monitorMethods[method]) {
				return _(monitorMethods[method].name);
			}
			return '-';
		};

		o = s.option(form.DummyValue, '_monitor_action_display', _('Actions'));
		o.cfgvalue = function(section_id) {
			var actions = uci.get('qmodem', section_id, 'monitor_action');
			if (!actions) return '-';
			if (!Array.isArray(actions)) actions = [actions];
			return actions.map(function(a) {
				return actionTypes[a] ? _(actionTypes[a].name) : a;
			}).join(', ');
		};

		// Modal options
		// ============= Monitor Method Selection =============
		o = s.option(form.ListValue, 'monitor_method', _('Monitor Method'));
		o.modalonly = true;
		o.default = 'ping';
		Object.keys(monitorMethods).forEach(function(key) {
			o.value(key, _(monitorMethods[key].name));
		});
		o.description = function(section_id) {
			var method = this.formvalue(section_id) || uci.get('qmodem', section_id, 'monitor_method');
			if (method && monitorMethods[method]) {
				return _(monitorMethods[method].description);
			}
			return '';
		};

		// ============= Ping Method Parameters =============
		// monitor_ping_type: Ping Type (ip/gateway/dns)
		o = s.option(form.ListValue, 'monitor_ping_type', _('Ping Type'));
		o.modalonly = true;
		o.value('ip', _('IP Address / Domain'));
		o.value('gateway', _('Gateway'));
		o.value('dns', _('DNS Server'));
		o.default = 'gateway';
		o.depends('monitor_method', 'ping');

		// monitor_ping_dest: Target for IP type (IP address or domain name)
		o = s.option(form.Value, 'monitor_ping_dest', _('Target IP / Domain'));
		o.modalonly = true;
		o.placeholder = '8.8.8.8 or www.example.com';
		o.description = _('Enter an IP address or domain name. Note: Using a domain name may cause false disconnection detection if DNS resolution fails.');
		o.depends({ 'monitor_method': 'ping', 'monitor_ping_type': 'ip' });

		// monitor_ping_ip_version: IP version for Gateway/DNS type
		o = s.option(form.ListValue, 'monitor_ping_ip_version', _('IP Version'));
		o.modalonly = true;
		o.value('4', 'IPv4');
		o.value('6', 'IPv6');
		o.default = '4';
		o.depends({ 'monitor_method': 'ping', 'monitor_ping_type': 'gateway' });
		o.depends({ 'monitor_method': 'ping', 'monitor_ping_type': 'dns' });

		// ============= Curl Method Parameters =============
		// monitor_http_url: URL for curl method
		o = s.option(form.Value, 'monitor_http_url', _('URL'));
		o.modalonly = true;
		o.placeholder = 'http://www.example.com';
		o.default = 'http://www.baidu.com';
		o.depends('monitor_method', 'curl');

		// ============= Common Parameters =============
		o = s.option(form.Value, 'monitor_interval', _('Check Interval (seconds)'));
		o.modalonly = true;
		o.datatype = 'uinteger';
		o.default = '15';
		o.placeholder = '15';

		o = s.option(form.Value, 'monitor_threshold', _('Failure Threshold'));
		o.modalonly = true;
		o.datatype = 'uinteger';
		o.default = '3';
		o.placeholder = '3';
		o.description = _('Number of consecutive failures before triggering actions');

		// ============= Action Selection =============
		o = s.option(form.MultiValue, 'monitor_action', _('Actions'));
		o.modalonly = true;
		Object.keys(actionTypes).forEach(function(key) {
			o.value(key, _(actionTypes[key].name));
		});
		o.description = _('Actions to perform when monitor threshold is reached');

		// ============= Action Parameters =============
		// AT Commands for send_at_commands action
		o = s.option(form.DynamicList, 'at_command', _('AT Commands'));
		o.modalonly = true;
		o.placeholder = 'AT+CFUN=1,1';
		o.description = _('AT commands to send when action is triggered');
		o.depends({ 'monitor_action': /send_at_commands/ });

		// Scripts for run_scripts action
		o = s.option(form.DynamicList, 'script', _('Script Paths'));
		o.modalonly = true;
		o.placeholder = '/usr/bin/my_script.sh';
		o.description = _('Scripts to execute when action is triggered');
		o.depends({ 'monitor_action': /run_scripts/ });

		return m.render();
	},

	updateRcStatus: function() {
		var self = this;
		return callRcStatus('qmodem_monitor').then(function(result) {
			self.rcStatusData = result;
			var status = result && result.qmodem_monitor ? result.qmodem_monitor : null;
			
			// Update status display
			var statusContainer = document.getElementById('rc-status-container');
			if (statusContainer && status) {
				var enabled = status.enabled === true || status.enabled === 'true';
				var running = status.running === true || status.running === 'true';
				
				statusContainer.innerHTML = '';
				statusContainer.appendChild(E('span', {}, _('Enabled') + ': ' + (enabled ? _('Yes') : _('No'))));
				statusContainer.appendChild(E('span', { 'style': 'margin-left: 12px;' }, _('Running') + ': ' + (running ? _('Yes') : _('No'))));
			}
			
			// Update control buttons
			var controlContainer = document.getElementById('rc-control-container');
			if (controlContainer && status) {
				var enabled = status.enabled === true || status.enabled === 'true';
				var running = status.running === true || status.running === 'true';
				
				controlContainer.innerHTML = '';
				var buttons = [];
				
				// Running control
				if (!running) {
					buttons.push(
						E('button', {
							'class': 'cbi-button cbi-button-action',
							'id': 'rc-start-button',
							'click': ui.createHandlerFn(self, function() {
								return callInitAction('qmodem_monitor', 'start')
									.then(function() {
										ui.addNotification(null, E('p', _('Monitor service started successfully')));
										return self.updateRcStatus();
									})
									.catch(function(err) {
										ui.addNotification(null, E('p', _('Failed to start monitor: ') + err.message), 'error');
										return self.updateRcStatus();
									});
							})
						}, _('Start'))
					);
				} else {
					buttons.push(
						E('button', {
							'class': 'cbi-button cbi-button-reset',
							'id': 'rc-stop-button',
							'click': ui.createHandlerFn(self, function() {
								return callInitAction('qmodem_monitor', 'stop')
									.then(function() {
										ui.addNotification(null, E('p', _('Monitor service stopped successfully')));
										return self.updateRcStatus();
									})
									.catch(function(err) {
										ui.addNotification(null, E('p', _('Failed to stop monitor: ') + err.message), 'error');
										return self.updateRcStatus();
									});
							})
						}, _('Stop'))
					);
					buttons.push(
						E('button', {
							'class': 'cbi-button cbi-button-apply',
							'id': 'rc-restart-button',
							'style': 'margin-left: 8px;',
							'click': ui.createHandlerFn(self, function() {
								return callInitAction('qmodem_monitor', 'restart')
									.then(function() {
										ui.addNotification(null, E('p', _('Monitor service restarted successfully')));
										return self.updateRcStatus();
									})
									.catch(function(err) {
										ui.addNotification(null, E('p', _('Failed to restart monitor: ') + err.message), 'error');
										return self.updateRcStatus();
									});
							})
						}, _('Restart'))
					);
				}
				
				buttons.push(E('span', { 'style': 'margin: 0 8px;' }, ' | '));

				// Enabled control
				if (!enabled) {
					buttons.push(
						E('button', {
							'class': 'cbi-button cbi-button-apply',
							'id': 'rc-enable-button',
							'click': ui.createHandlerFn(self, function() {
								return callInitAction('qmodem_monitor', 'enable')
									.then(function() {
										ui.addNotification(null, E('p', _('Monitor service enabled successfully')));
										return self.updateRcStatus();
									})
									.catch(function(err) {
										ui.addNotification(null, E('p', _('Failed to enable monitor: ') + err.message), 'error');
										return self.updateRcStatus();
									});
							})
						}, _('Enable'))
					);
				} else {
					buttons.push(
						E('button', {
							'class': 'cbi-button cbi-button-negative',
							'id': 'rc-disable-button',
							'click': ui.createHandlerFn(self, function() {
								return callInitAction('qmodem_monitor', 'disable')
									.then(function() {
										ui.addNotification(null, E('p', _('Monitor service disabled successfully')));
										return self.updateRcStatus();
									})
									.catch(function(err) {
										ui.addNotification(null, E('p', _('Failed to disable monitor: ') + err.message), 'error');
										return self.updateRcStatus();
									});
							})
						}, _('Disable'))
					);
				}
				
				buttons.forEach(function(btn) {
					controlContainer.appendChild(btn);
				});
			}
		});
	}
});
