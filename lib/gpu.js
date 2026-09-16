// One device's measurements and baseline. External values never index a normal object.
function pciAddress(value) {
    var match = typeof value === "string" && /^(?:0000)?([0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7])$/i.exec(value);
    return match ? match[1].toLowerCase() : "";
}
function finite(value, lo, hi) {
    return typeof value === "number" && isFinite(value) && value >= lo && value <= hi;
}
function unavailable(device) {
    return { load: -1, temp: -1, vramTemp: -1, powerW: -1, energyUj: -1,
        hasVram: false, vramUsedGb: 0, vramTotalGb: device.knownVramTotalGb || 0, status: "offline" };
}
function intelDelta(clients, previous) {
    var next = Object.create(null), seen = Object.create(null), busy = 0, valid = false;
    clients.forEach(function(client) {
        if (!client || typeof client.id !== "string" || !/^\d+$/.test(client.id)
                || !Array.isArray(client.engines) || seen[client.id]) return;
        seen[client.id] = true;
        client.engines.forEach(function(engine) {
            if (!engine || typeof engine.name !== "string" || !engine.name
                    || !finite(engine.cycles, 0, Number.MAX_SAFE_INTEGER)
                    || !finite(engine.total, 0, Number.MAX_SAFE_INTEGER)
                    || !finite(engine.capacity, 1, 1024)) return;
            var key = client.id + ":" + engine.name;
            if (next[key]) return;
            var sample = { cycles: engine.cycles, total: engine.total, capacity: engine.capacity };
            next[key] = sample;
            var old = previous && previous[key];
            if (!old || sample.total < old.total || sample.capacity !== old.capacity) return;
            if (sample.cycles < old.cycles) {
                // Kernel counters may briefly regress; retain the high-water mark.
                sample.cycles = old.cycles;
                return;
            }
            var dt = sample.total - old.total;
            if (dt <= 0) return;
            busy += 100 * (sample.cycles - old.cycles) / (dt * sample.capacity);
            valid = true;
        });
    });
    return { clients: next, load: valid ? Math.round(Math.max(0, Math.min(100, busy))) : -1 };
}
function sampleResult(text, device, previous) {
    var sample;
    try { sample = JSON.parse(text); } catch (_) { return null; }
    if (!sample || pciAddress(sample.pci) !== device.pci || !sample.metrics
            || typeof sample.metrics !== "object" || Array.isArray(sample.metrics)
            || !finite(sample.monotonicMs, 0, Number.MAX_SAFE_INTEGER)
            || (device.vendor === "intel" && !Array.isArray(sample.clients))) return null;
    var patch = unavailable(device), metrics = sample.metrics;
    if (finite(metrics.load, 0, 100)) patch.load = Math.round(metrics.load);
    if (finite(metrics.temp, 0, 200)) patch.temp = Math.round(metrics.temp);
    if (finite(metrics.vramTemp, 0, 200)) patch.vramTemp = Math.round(metrics.vramTemp);
    if (finite(metrics.vramTotalGb, 0.001, 65536)) patch.vramTotalGb = metrics.vramTotalGb;
    if (finite(metrics.vramUsedGb, 0, 65536) && patch.vramTotalGb > 0) {
        patch.vramUsedGb = metrics.vramUsedGb;
        patch.hasVram = true;
    }
    var state = { clients: Object.create(null), time: sample.monotonicMs, energy: null };
    if (device.vendor === "intel") {
        var delta = intelDelta(sample.clients, previous ? previous.clients : null);
        state.clients = delta.clients;
        patch.load = delta.load;
    }
    if (finite(metrics.energyUj, 0, Number.MAX_SAFE_INTEGER)) {
        patch.energyUj = state.energy = metrics.energyUj;
        if (previous && previous.energy !== null && state.energy >= previous.energy && state.time > previous.time)
            patch.powerW = (state.energy - previous.energy) / ((state.time - previous.time) * 1000);
    }
    if (patch.load >= 0) patch.status = "ok";
    else if (patch.temp >= 0 || patch.vramTemp >= 0 || patch.hasVram) patch.status = "sensor";
    return { patch: patch, state: state };
}
