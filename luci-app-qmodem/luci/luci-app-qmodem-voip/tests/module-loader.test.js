'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const resourceDir = path.resolve(__dirname,
	'../htdocs/luci-static/resources/qmodem-voip');
const instances = {};
const baseclass = {
	extend(properties) {
		function LuCIModule() {}
		Object.assign(LuCIModule.prototype, properties);
		return LuCIModule;
	}
};

function load(name) {
	const source = fs.readFileSync(path.join(resourceDir, `${name}.js`), 'utf8');
	const dependencies = [ ...source.matchAll(/^'require ([^']+)'/gm) ].map((match) => {
		const parts = match[1].split(/\s+as\s+/);
		return { name: parts[0], argument: parts[1] || parts[0].replace(/[^a-zA-Z0-9_]/g, '_') };
	});
	const values = dependencies.map((dependency) => {
		if (dependency.name === 'baseclass')
			return baseclass;
		if (dependency.name === 'rpc')
			return { declare: (specification) => () => specification };
		return instances[dependency.name];
	});
	const factory = new Function('window', 'document', 'L', 'module',
		...dependencies.map((dependency) => dependency.argument), source);
	const Constructor = factory({}, {}, {}, { exports: {} }, ...values);
	assert.equal(typeof Constructor, 'function', `${name} must yield a constructor`);
	instances[`qmodem-voip.${name}`] = new Constructor();
	return instances[`qmodem-voip.${name}`];
}

const contract = load('contract');
assert.equal(contract.OBJECT, 'qmodem_voip');
const rpc = load('rpc');
assert.equal(rpc.eventTopic, contract.EVENT_TOPIC);
assert.equal(typeof rpc.status, 'function');
assert.equal(typeof load('surface').build, 'function');
assert.equal(typeof load('reducer').reduce, 'function');
assert.equal(typeof load('media').createMediaClient, 'function');

console.log('PASS: qmodem voip LuCI module loader contract');
