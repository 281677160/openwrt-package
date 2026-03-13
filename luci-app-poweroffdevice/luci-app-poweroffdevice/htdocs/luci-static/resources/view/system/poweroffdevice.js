'use strict';
'require view';
'require ui';
'require fs';

return view.extend({
    render: function() {
        return E([
            E('div', { class: 'cbi-section' }, [
                E('h2', { class: 'cbi-section-title' }, _('PowerOff')),
                E('div', { class: 'cbi-section-descr' }, _('Turn off the power to the device you are using')),
                E('hr', { style: 'margin: 15px 0' }),
                E('div', { style: ' padding: 20px 0' }, [
                    E('button', {
                        class: 'btn cbi-button cbi-button-negative important',
                        style: 'padding: 0.5rem 1rem;font-size: 1.2em;font-weight: bold;border-radius: 4px;box-shadow: 0 2px 5px rgba(0,0,0,0.2);',
                        click: ui.createHandlerFn(this, 'handlePowerOff')
                    }, _('⚠️ Perform Power Off'))
                ])
            ])
        ]);
    },

    handlePowerOff: function() {
        return ui.showModal(_('⚠️ PowerOff Device'), 
            E('div', { style: 'min-width: 350px' }, [
                E('div', { class: 'alert-message warning', style: 'margin: 0 0 15px 0; padding: 10px;  background: #f0ad4e' }, [
                    E('h4', { style: 'margin: 0 0 5px 0; ' }, _('Warning!')),
                    E('p', { style: 'margin: 0; ' }, _('This action will immediately turn off the power to your device. Make sure to save all your work before proceeding.'))
                ]),

                E('div', { style: ' border-radius: 4px; padding: 15px; margin-bottom: 15px' }, [
                    E('p', { style: 'margin: 0 0 10px 0; font-weight: bold' }, _('Before you continue:')),
                    E('ul', { style: 'margin: 0; padding-left: 20px' }, [
                        E('li', { style: 'margin-bottom: 5px' }, _('Save all unsaved settings')),
                        E('li', { style: 'margin-bottom: 5px' }, _('Check if other users are active')),
                        E('li', _('The device needs to be manually turned on'))
                    ])
                ]),

                E('div', { class: 'right', style: 'margin-top: 20px; padding-top: 15px; border-top: 1px solid #ddd' }, [
                    E('button', {
                        'class': 'btn cbi-button cbi-button-apply',
                        'style': 'margin-right: 10px; ',
                        'click': ui.hideModal
                    }, _('Cancel')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-negative',
                        'style': ' font-weight: bold;',
                        'click': ui.createHandlerFn(this, function() {
                            ui.hideModal();
                            
                            // Show powering off modal
                            ui.showModal(_('Powering Off'), 
                                E('div', { style: 'text-align: center; padding: 30px; min-width: 300px' }, [
                                    E('div', { 
                                        class: 'spinning', 
                                        style: 'font-size: 48px; margin-bottom: 20px; color: #f0ad4e;' 
                                    }, '⚡'),
                                    E('h3', { style: 'margin: 0 0 15px 0' }, _('Powering off device...')),
                                    E('p', { style: 'color: #666; margin: 0' }, 
                                        _('The device should power off within a few seconds. If the device remains on, you may need to perform a manual shutdown.'))
                                ])
                            );

                            // Execute poweroff command
                            return fs.exec('/sbin/poweroff').catch(function(e) {
                                ui.hideModal();
                                ui.addNotification(null, 
                                    E('div', { style: 'padding: 10px' }, [
                                        E('h4', { style: 'color: #d9534f; margin: 0 0 5px 0' }, _('Error!')),
                                        E('p', { style: 'margin: 0' }, e.message)
                                    ])
                                );
                            });
                        })
                    }, _('Confirm Power Off'))
                ])
            ])
        );
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});