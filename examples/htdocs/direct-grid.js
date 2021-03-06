/*

This file is part of Ext JS 4

Copyright (c) 2011 Sencha Inc

Contact:  http://www.sencha.com/contact

Commercial Usage
Licensees holding valid commercial licenses may use this file in accordance with the Commercial Software License Agreement provided with the Software or, alternatively, in accordance with the terms contained in a written agreement between you and Sencha.

If you are unsure which license is appropriate for your use, please contact the sales department at http://www.sencha.com/contact.

*/
Ext.require([
    'Ext.direct.*',
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.util.Format'
]);

Ext.define('Company', {
    extend: 'Ext.data.Model',
    fields: ['name', 'turnover']
});

Ext.onReady(function() {    
    Ext.direct.Manager.addProvider(Ext.app.REMOTING_API);
    
    
    // create the Tree
    Ext.create('Ext.grid.Panel', {
        store: {
            model: 'Company',
            remoteSort: true,
            autoLoad: true,
            sorters: [{
                property: 'name',
                direction: 'ASC'
            }],
            proxy: {
                type: 'direct',
                directFn: TestAction.getGrid
            }
        },
        columns: [{
            dataIndex: 'name',
            flex: 1,
            text: 'Name'
        }, {
            dataIndex: 'turnover',
            align: 'right',
            width: 120,
            text: 'Turnover pa.',
            renderer: Ext.util.Format.usMoney
        }],
        height: 350,
        width: 600,
        title: 'Company Grid',
        renderTo: Ext.getBody()
    });
});
