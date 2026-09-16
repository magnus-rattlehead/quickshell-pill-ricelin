const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const gpu = vm.createContext({});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../lib/gpu.js'), 'utf8'), gpu);
const client = (id, cycles, total, capacity=1) => ({id, engines:[{name:'render',cycles,total,capacity}]});
const device = {pci:'0000:0e:00.0',vendor:'intel',knownVramTotalGb:12};
const sample = (clients, metrics={}, monotonicMs=100) => JSON.stringify({pci:device.pci,clients,metrics,monotonicMs});
test('Intel warmup, capacity, idle, and duplicate clients', () => {
    let a = gpu.intelDelta([client('1',10,100,2)], null);
    assert.equal(a.load,-1);
    let b = gpu.intelDelta([client('1',110,200,2),client('1',999,200,2)], a.clients);
    assert.equal(b.load,50);
    assert.equal(gpu.intelDelta([client('1',110,300,2)],b.clients).load,0);
});
test('client churn cannot create utilization spikes', () => {
    let a = gpu.intelDelta([client('1',100,1000),client('2',800,1000)],null);
    let b = gpu.intelDelta([client('1',120,1100),client('3',9000,1100)],a.clients);
    assert.equal(b.load,20);
    assert.equal(Object.keys(b.clients).length,2);
    assert.equal(gpu.intelDelta([client('2',900,1200)],b.clients).load,-1);
});
test('counter regression, reset, capacity change and invalid counters', () => {
    let a = gpu.intelDelta([client('1',100,1000)],null);
    let b = gpu.intelDelta([client('1',90,1100)],a.clients);
    assert.equal(b.load,-1);
    assert.equal(gpu.intelDelta([client('1',120,1200)],b.clients).load,20);
    assert.equal(gpu.intelDelta([client('1',1,1)],b.clients).load,-1);
    assert.equal(gpu.intelDelta([client('1',120,1200,2)],b.clients).load,-1);
    assert.equal(gpu.intelDelta([client('1',Infinity,1200)],b.clients).load,-1);
    assert.equal(gpu.intelDelta([client('1',2**54,1200)],b.clients).load,-1);
});
test('result validation rejects wrong devices and malformed samples', () => {
    assert.equal(gpu.sampleResult('bad',device,null),null);
    assert.equal(gpu.sampleResult(sample([]).replace('0e:','0b:'),device,null),null);
    assert.equal(gpu.sampleResult(sample(null),device,null),null);
    const result = gpu.sampleResult(sample([], {temp:999,vramUsedGb:0}),device,null);
    assert.equal(result.patch.temp,-1);
    assert.equal(result.patch.hasVram,true);
    assert.equal(result.patch.vramUsedGb,0);
});
test('energy and utilization baselines reset on reopen', () => {
    const a = gpu.sampleResult(sample([client('1',1,100)],{energyUj:1000},100),device,null);
    const b = gpu.sampleResult(sample([client('1',51,200)],{energyUj:10001000},300),device,a.state);
    assert.equal(b.patch.load,50);
    assert.equal(b.patch.powerW,50);
    const reopened = gpu.sampleResult(sample([client('1',51,200)],{energyUj:10001000},300),device,null);
    assert.equal(reopened.patch.load,-1);
    assert.equal(reopened.patch.powerW,-1);
});
