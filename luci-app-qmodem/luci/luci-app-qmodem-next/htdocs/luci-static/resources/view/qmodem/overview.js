'use strict';
'require view';
'require poll';
'require ui';
'require dom';
'require uci';
'require qmodem.qmodem as qmodem';

// Load CSS
document.head.appendChild(E('link', {
	'rel': 'stylesheet',
	'type': 'text/css',
	'href': L.resource('qmodem/qmodem-next.css')
}));

// Check if cbi-progressbar class exists
function hasCssClass(className) {
	var styleSheets = document.styleSheets;
	for (var i = 0; i < styleSheets.length; i++) {
		try {
			var rules = styleSheets[i].cssRules || styleSheets[i].rules;
			if (rules) {
				for (var j = 0; j < rules.length; j++) {
					if (rules[j].selectorText && rules[j].selectorText.indexOf(className) !== -1) {
						return true;
					}
				}
			}
		} catch(e) {
			// Cross-origin stylesheet, skip
		}
	}
	return false;
}

var progressbar_className = hasCssClass('.cbi-progressbar') ? 'cbi-progressbar' : 'compat-progressbar';

// LuciTable class for rendering modem info tables
var LuciTable = function() {
	this.rows = [];
	this.tbody = null;
	this.fieldset = null;
	this.initTable();
};

LuciTable.prototype = {
	initTable: function() {
		this.fieldset = E('fieldset', { 'class': 'cbi-section' });
		this.legend = E('legend', {});
		this.title_span = E('h2', { 'class': 'panel-title' });
		var table = E('table', { 'class': 'table' });
		this.tbody = E('tbody', { 'style': 'width: 100%' });
		
		table.appendChild(this.tbody);
		this.fieldset.appendChild(this.legend);
		this.fieldset.appendChild(this.title_span);
		this.fieldset.appendChild(table);
	},

	setTitle: function(value) {
		// Translate class name
		var translatedValue = _(value);
		this.legend.textContent = translatedValue;
		this.title_span.textContent = translatedValue;
	},

	newTr: function(data, index) {
		var type = data.type;
		switch(type) {
			case 'plain_text':
				var key = data.key;
				var value = data.value;
				var full_name = data.full_name || key;
				var extra_info = data.extra_info;
				
				// Translate full_name and extra_info
				var translatedName = _(full_name);
				var displayName = extra_info ? translatedName + ' (' + extra_info + ')' : translatedName;
				
				this.rows[index].left.textContent = displayName;
				this.rows[index].right.textContent = value;

				if (value == null || value == '') {
					this.rows[index].row.style.display = 'none';
				} else {
					this.rows[index].row.style.display = '';
				}
				break;
				
			case 'progress_bar':
				var key = data.key;
				var full_name = data.full_name || key;
				var extra_info = data.extra_info;
				var value = parseFloat(data.value);
				var min = parseFloat(data.min_value);
				var max = parseFloat(data.max_value);
				var unit = data.unit || '';
				var title = '(' + data.value + '/' + data.max_value + unit + ')';
				var percentage = ((value - min) / (max - min)) * 100;
				
				// Clamp percentage between 0 and 100
				percentage = Math.max(0, Math.min(100, percentage));
				
				// Translate full_name and extra_info
				var translatedName = _(full_name);
				var displayName = extra_info ? translatedName + ' (' + extra_info + ')' : translatedName;
				
				this.rows[index].left.textContent = displayName;
				
				var progress_bar = E('div', { 
					'class': progressbar_className,
					'title': title
				});
				var progress_bar_bar = E('div', { 'style': 'width:' + percentage + '%' });
				progress_bar.appendChild(progress_bar_bar);
				
				this.rows[index].right.innerHTML = '';
				this.rows[index].right.appendChild(progress_bar);
				
				this.rows[index].row.style.display = '';
				break;
		}
	},

	setData: function(value) {
		if (value == null) return;
		
		if (Array.isArray(value)) {
			this.setArrayData(value);
		} else {
			this.setObjectData(value);
		}
	},

	setArrayData: function(value) {
		var row_length = this.rows.length;
		var value_length = value.length;
		
		// Add missing rows
		if (row_length < value_length) {
			for (var i = row_length; i < value_length; i++) {
				var row = E('tr', { 'class': 'tr' });
				var cell_left = E('td', { 'class': 'td left', 'width': '33%' });
				var cell_right = E('td', { 'class': 'td' });
				row.appendChild(cell_left);
				row.appendChild(cell_right);
				this.tbody.appendChild(row);
				
				this.rows.push({
					row: row,
					left: cell_left,
					right: cell_right
				});
			}
		}
		// Remove extra rows
		else if (row_length > value_length) {
			for (var i = value_length; i < row_length; i++) {
				this.tbody.removeChild(this.rows[i].row);
			}
			this.rows = this.rows.slice(0, value_length);
		}
		
		// Update row content
		for (var i = 0; i < value.length; i++) {
			this.newTr(value[i], i);
		}
	},

	setObjectData: function(value) {
		var row_length = this.rows.length;
		var value_length = Object.keys(value).length;
		
		// Add missing rows
		if (row_length < value_length) {
			for (var i = row_length; i < value_length; i++) {
				var row = E('tr', { 'class': 'tr' });
				var cell_left = E('td', { 'class': 'td left', 'width': '33%' });
				var cell_right = E('td', { 'class': 'td' });
				row.appendChild(cell_left);
				row.appendChild(cell_right);
				this.tbody.appendChild(row);
				
				this.rows.push({
					row: row,
					left: cell_left,
					right: cell_right
				});
			}
		}
		// Remove extra rows
		else if (row_length > value_length) {
			for (var i = value_length; i < row_length; i++) {
				this.tbody.removeChild(this.rows[i].row);
			}
			this.rows = this.rows.slice(0, value_length);
		}
		
		// Update row content
		var index = 0;
		for (var key in value) {
			this.rows[index].left.textContent = key;
			this.rows[index].right.textContent = value[key];
			index++;
		}
	}
};

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('qmodem')
		]);
	},

	getModemList: function() {
		var modems = [];
		var sections = uci.sections('qmodem', 'modem-device');
		
		sections.forEach(function(section) {
			if (section.state !== 'disabled' && section.at_port) {
				var name = section.name ? section.name.toUpperCase() : 'Unknown';
				var displayName = section.alias ? section.alias + ' (' + name + ')' : name;
				
				modems.push({
					id: section['.name'],
					name: displayName,
					at_port: section.at_port
				});
			}
		});
		
		return modems;
	},

	updateModemInfo: function(modemId, tables_map, infoContainer, updateTimeElement) {
		var self = this;
		
		// Show loading state
		if (Object.keys(tables_map).length === 0) {
			dom.content(infoContainer, E('div', { 'class': 'spinning' }, _('Loading modem information...')));
		}
		
		// Fetch all modem info
		Promise.all([
			qmodem.getBaseInfo(modemId),
			qmodem.getSimInfo(modemId),
			qmodem.getNetworkInfo(modemId),
			qmodem.getCellInfo(modemId)
		]).then(function(results) {
			// Merge all modem_info arrays
			var all_info = [];
			results.forEach(function(result) {
				if (result && result.modem_info) {
					all_info = all_info.concat(result.modem_info);
				}
			});

			// Group by class
			var grouped = {};
			all_info.forEach(function(entry) {
				if (entry.type === 'warning_message') {
					// Handle warning messages
					return;
				}
				
				var className = entry['class'] || 'General';
				if (!grouped[className]) {
					grouped[className] = [];
				}
				grouped[className].push(entry);
			});

			// Clear loading animation if present
			var loadingDiv = infoContainer.querySelector('.spinning');
			if (loadingDiv) {
				infoContainer.removeChild(loadingDiv);
			}

			// Remove obsolete tables from DOM and map
			for (var existingClass in tables_map) {
				if (!grouped[existingClass]) {
					if (tables_map[existingClass].fieldset.parentNode) {
						infoContainer.removeChild(tables_map[existingClass].fieldset);
					}
					delete tables_map[existingClass];
				}
			}

			// Update or create tables
			for (var className in grouped) {
				if (!tables_map[className]) {
					tables_map[className] = new LuciTable();
					infoContainer.appendChild(tables_map[className].fieldset);
				}
				tables_map[className].setTitle(className);
				tables_map[className].setData(grouped[className]);
			}
			
			// Update refresh time
			if (updateTimeElement) {
				var now = new Date();
				var timeStr = now.getFullYear() + '-' + 
					String(now.getMonth() + 1).padStart(2, '0') + '-' + 
					String(now.getDate()).padStart(2, '0') + ' ' + 
					String(now.getHours()).padStart(2, '0') + ':' + 
					String(now.getMinutes()).padStart(2, '0') + ':' + 
					String(now.getSeconds()).padStart(2, '0');
				updateTimeElement.textContent = _('Last update') + ': ' + timeStr;
			}
		}).catch(function(e) {
			console.error('Error fetching modem info:', e);
			dom.content(infoContainer, E('div', { 'class': 'alert-message warning' },
				_('Error loading modem information: %s').format(e.message)));
		});
	},

	render: function() {
		var self = this;
		var modems = this.getModemList();
		
		if (modems.length === 0) {
			return E('div', { 'class': 'alert-message warning' }, 
				_('No modems configured or all modems are disabled.'));
		}

		var container = E('div', { 'class': 'cbi-map' });
		
		// Create modem selector section
		var selectorSection = E('fieldset', { 'class': 'cbi-section' });
		var selectorTable = E('table', { 'class': 'table' });
		var selectorBody = E('tbody', {});
		var selectorRow = E('tr', { 'class': 'tr' });
		var labelCell = E('td', { 'class': 'td', 'width': '33%' }, _('Modem Name'));
		var selectCell = E('td', { 'class': 'td' });
		
		// Create select dropdown
		var select = E('select', {
			'class': 'cbi-input-select',
			'id': 'modem_selector'
		});
		
		modems.forEach(function(modem) {
			select.appendChild(E('option', { 'value': modem.id }, modem.name));
		});
		
		selectCell.appendChild(select);
		selectorRow.appendChild(labelCell);
		selectorRow.appendChild(selectCell);
		selectorBody.appendChild(selectorRow);
		selectorTable.appendChild(selectorBody);
		selectorSection.appendChild(selectorTable);
		container.appendChild(selectorSection);
		
		// Create update time display
		var updateTimeSection = E('fieldset', { 'class': 'cbi-section' });
		var updateTimeDiv = E('div', { 
			'style': 'text-align: right; padding: 5px; color: #888;',
			'id': 'update_time_display'
		}, _('Last update') + ': -');
		updateTimeSection.appendChild(updateTimeDiv);
		container.appendChild(updateTimeSection);
		
		// Create info container
		var infoContainer = E('div', { 'id': 'modem_info_container' });
		container.appendChild(infoContainer);
		
		// Tables map to store LuciTable instances
		var tables_map = {};
		
		// Update function
		var updateInfo = function(clearTables) {
			var selectedModem = select.value;
			
			// Clear tables when switching modem
			if (clearTables) {
				for (var className in tables_map) {
					if (tables_map[className].fieldset.parentNode) {
						infoContainer.removeChild(tables_map[className].fieldset);
					}
				}
				tables_map = {};
			}
			
			self.updateModemInfo(selectedModem, tables_map, infoContainer, updateTimeDiv);
		};
		
		// Selector change handler
		select.addEventListener('change', function() {
			updateInfo(true); // Clear tables when switching
		});
		
		// Initial update
		updateInfo(false);
		
		// Start polling (every 10 seconds)
		poll.add(function() {
			var selectedModem = select.value;
			self.updateModemInfo(selectedModem, tables_map, infoContainer, updateTimeDiv);
		}, 10);
		
		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
