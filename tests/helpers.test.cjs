const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
function load(name) {
    const context = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../lib', name), 'utf8'), context);
    return context;
}
const safe = load('safe.js'), network = load('network.js'), weather = load('weather.js');
const plain = x => JSON.parse(JSON.stringify(x));

test('shell argument serialization preserves adversarial values without execution', () => {
    const values = ['', 'two words', "O'Reilly", '"quoted"', '\\', '\n\t\r', '; exit 31', '$(exit 32)', '`exit 33`', '--help', 'é'];
    const result = spawnSync('sh', ['-c', "printf '%s\\0' " + safe.commandString(values)], {encoding:'utf8'});
    assert.equal(result.status, 0);
    assert.deepEqual(result.stdout.split('\0').slice(0, -1), values);
    assert.throws(() => safe.shellQuote('bad\0argument'));
});

test('Lua quoting escapes string terminators and every control byte', () => {
    assert.equal(safe.luaQuote('a"\\\n\r\0\t9'), '"a\\"\\\\\\010\\013\\000\\0099"');
    for (let i = 0; i < 32; i++) assert(!safe.luaQuote(String.fromCharCode(i)).includes(String.fromCharCode(i)));
    assert.equal(safe.windowAddress('0xabc123'), '0xabc123');
    for (const value of ['null', '0x1" }); os.exit(); --', {}, null]) assert.equal(safe.windowAddress(value), '');
    for (const value of ['1;exit', -1, 0, 1.5, Infinity]) assert.equal(safe.workspaceId(value), 0);
});

test('usage data rejects malformed shapes and prototype keys remain ordinary data', () => {
    for (const data of ['null', '[]', '"x"', 'not json']) assert.deepEqual(plain(safe.usageFromJson(data)), {});
    const usage = safe.usageFromJson('{"constructor":2,"__proto__":4,"good":1,"negative":-1,"bad":"3","huge":1e99}');
    assert.equal(Object.getPrototypeOf(usage), null);
    assert.equal(usage.constructor, 2);
    assert.equal(usage.__proto__, 4);
    assert.deepEqual(Object.keys(usage).sort(), ['__proto__', 'constructor', 'good']);
});

test('nmcli fields handle escaped colons, backslashes, and trailing backslashes', () => {
    assert.deepEqual(plain(network.fields('Cafe\\: west:WPA2')), ['Cafe: west','WPA2']);
    assert.deepEqual(plain(network.fields('Ends\\\\:WPA3')), ['Ends\\','WPA3']);
    assert.deepEqual(plain(network.fields('a\\\\\\:b:')), ['a\\:b','']);
    assert.equal(network.fields('bad\\'), null);
    assert.equal(network.fields('bad\\x:WPA2'), null);
    assert.equal(network.lineInput('secret\nsecond-command'), false);
    assert.equal(network.lineInput('quotes\' $(literal)'), true);
    assert.equal(network.mac('00:11:22:aa:BB:FF'), true);
    assert.equal(network.mac(':::::::::::::::::'), false);
    assert.equal(network.uuid('00000000-0000-0000-0000-000000000001'), true);
});

test('manual weather cache is tied to its city query and bounded coordinates', () => {
    assert.equal(weather.cachedLocation('{"lat":45,"lon":-73,"city":"Old"}', 'New'), null);
    assert.equal(weather.cachedLocation('{"query":"Old","lat":45,"lon":-73,"city":"Old"}', 'New'), null);
    assert.equal(weather.coordinates(91,0), false);
    assert.equal(weather.coordinates(0,Infinity), false);
    assert.equal(weather.location('{"results":[{"name":"Montreal","latitude":45,"longitude":-73}]}','Montreal').query, 'Montreal');
});

test('weather response validation rejects malformed current values and skips invalid rows', () => {
    assert.equal(weather.forecast('{"current":{"temperature_2m":"20"}}', '2026-09-16'), null);
    const data = {current:{temperature_2m:20.4,weather_code:1,relative_humidity_2m:50,is_day:1},
        hourly:{time:['2026-09-16T10:00',null],temperature_2m:[20,21],weather_code:[1,2]},
        daily:{time:['2026-09-15','2026-09-16','2026-02-30'],weather_code:[1,2,3],temperature_2m_max:[20,21,22],relative_humidity_2m_mean:[50,60,70]}};
    const result = weather.forecast(JSON.stringify(data),'2026-09-16');
    assert.equal(result.tempNow,20);
    assert.equal(result.hourly.length,1);
    assert.equal(result.daily.length,1);
    assert.equal(result.daily[0].day,'Wed');
});
