const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

test('resources without document type or client timestamp remain readable and updatable', async () => {
    const sandbox = { module: { exports: {} }, Buffer, require(name) {
        assert.equal(name, 'fabric-contract-api');
        return { Contract: class {} };
    } };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../lib/resource-events-v2.js'), 'utf8'), sandbox);
    const contract = new sandbox.module.exports();
    const state = new Map();
    let closed = false;
    let seconds = 1800000000;
    const ctx = {
        clientIdentity: { getID: () => 'alice', getMSPID: () => 'Org1MSP', getAttributeValue: () => null },
        stub: {
            getState: async key => state.get(key),
            putState: async (key, value) => state.set(key, value),
            getTxTimestamp: () => ({ seconds }), getTxID: () => `tx-${seconds}`,
            setEvent() {},
            createCompositeKey: (type, attributes) => ['\0', type, ...attributes].join('|'),
            splitCompositeKey: key => ({ attributes: key.split('|').slice(2) }),
            async getStateByPartialCompositeKey(type) {
                const entries = [...state].filter(([key]) => key.startsWith(`\0|${type}|`));
                let index = 0;
                return {
                    async next() {
                        if (index === entries.length) return { done: true };
                        const [key, value] = entries[index++];
                        return { done: false, value: { key, value } };
                    },
                    async close() { closed = true; },
                };
            },
        },
    };
    const resource = JSON.parse(await contract.CreateResource(ctx, 'pid:1', 'https://example.test', 'abc', '["Org1MSP"]'));
    assert.equal(Object.hasOwn(resource, 'docType'), false);
    assert.equal(Object.hasOwn(resource, 'clientTimestamp'), false);
    assert.equal(resource.timestamp, seconds);
    assert.deepEqual(resource.owners, ['Org1MSP']);
    state.set('unrelated', Buffer.from('{"other":true}'));
    assert.deepEqual(JSON.parse(await contract.ReadAllResources(ctx)), [resource]);
    assert.equal(closed, true);
    assert.deepEqual(JSON.parse(await contract.GetResourcesByTimestamp(ctx, String(seconds), String(seconds))), [resource]);
    seconds++;
    const updated = JSON.parse(await contract.UpdateResourceStatus(ctx, 'pid:1', '1'));
    assert.equal(updated.status, 1);
    assert.equal(updated.updatedAt, seconds);
    assert.equal(Object.hasOwn(updated, 'docType'), false);
    assert.equal(Object.hasOwn(updated, 'clientTimestamp'), false);
    assert.deepEqual(JSON.parse(await contract.ReadResource(ctx, 'pid:1')), updated);
});
