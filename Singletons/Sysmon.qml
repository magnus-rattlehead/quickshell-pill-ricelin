pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../lib/gpu.js" as Gpu

Singleton {
    id: root

    property bool open: false

    property int cpu: 0
    property int cpuTemp: -1

    property var gpus: []
    // Stable descriptors: measurements update gpus, never this collector model.
    property var gpuDevices: []
    property bool hasGpu: false
    property string gpuVendor: "none"
    property string amdDev: ""
    property int gpu: 0
    property int gpuTemp: -1
    property bool hasVram: false
    property real vramUsedGb: 0
    property real vramTotalGb: 0

    property real memUsedGb: 0
    property real memTotalGb: 0
    property int memPct: 0
    property real swapUsedGb: 0

    property real netDown: 0
    property real netUp: 0

    property int diskPct: 0
    property string uptime: ""

    property bool detected: false
    property string tempPath: ""

    property real prevCpuTotal: 0
    property real prevCpuIdle: 0
    property real prevRx: 0
    property real prevTx: 0
    property real prevNetTime: 0

    function primeAll() {
        if (!detected) {
            detectProc.running = true;
            return;
        }
        prevCpuTotal = 0;
        prevRx = 0;
        prevNetTime = 0;
        fastProc.running = true;
        slowProc.running = true;
    }

    onOpenChanged: if (open) primeAll()

    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var hh = h < 10 ? "0" + h : "" + h;
        var mm = m < 10 ? "0" + m : "" + m;
        return "UP " + d + "D " + hh + ":" + mm;
    }

    function cleanLabel(vendor, raw) {
        var label = (raw || "").replace(/\s+/g, " ").trim();
        if (vendor === "intel") {
            if (label.indexOf("Arc B580") >= 0)
                return "Arc B580";
            if (label.indexOf("Arc") >= 0) {
                var arc = label.match(/Arc [A-Za-z0-9 -]+/);
                if (arc)
                    return arc[0].replace(/\s+\[[^\]]+\].*$/, "").trim();
            }
            return "Intel GPU";
        }
        if (vendor === "nvidia") {
            if (label.indexOf("RTX 3090") >= 0)
                return "RTX 3090";
            var geforce = label.match(/\[GeForce ([^\]]+)\]/);
            if (geforce)
                return geforce[1];
            return label.replace(/^.*NVIDIA Corporation\s+/, "").replace(/\s+\[[^\]]+\].*$/, "").trim() || "NVIDIA GPU";
        }
        if (vendor === "amd")
            return label.replace(/^.*Advanced Micro Devices, Inc\. \[AMD\/ATI\]\s+/, "").replace(/\s+\[[^\]]+\].*$/, "").trim() || "AMD GPU";
        return label || "GPU";
    }

    function shortLabel(vendor, label) {
        var up = (label || "").toUpperCase();
        if (vendor === "intel" && up.indexOf("ARC") >= 0) {
            var arc = (label || "").match(/Arc\s+[A-Za-z0-9]+/i);
            return arc ? arc[0] : "Intel Arc";
        }
        if (up.indexOf("RTX 3090") >= 0)
            return "RTX 3090";
        if (up.indexOf("RTX") >= 0) {
            var rtx = up.match(/RTX\s+[0-9A-Z]+/);
            if (rtx)
                return rtx[0];
        }
        if (vendor === "nvidia")
            return "NVIDIA";
        if (vendor === "intel")
            return "INTEL";
        if (vendor === "amd")
            return "AMD";
        return "GPU";
    }

    function knownVramTotalGb(vendor, label, deviceId) {
        var l = (label || "").toUpperCase();
        var dev = (deviceId || "").toLowerCase();
        if (vendor === "intel" && (dev === "0xe20b" || l.indexOf("ARC B580") >= 0))
            return 12;
        if (vendor === "nvidia" && l.indexOf("RTX 3090") >= 0)
            return 24;
        return 0;
    }

    function emptyGpu(id, vendor, label, pci, devPath, deviceId) {
        var clean = cleanLabel(vendor, label);
        var knownVram = knownVramTotalGb(vendor, clean, deviceId);
        return {
            "id": id,
            "vendor": vendor,
            "label": clean,
            "shortLabel": shortLabel(vendor, clean),
            "pci": pci || "",
            "devPath": devPath || "",
            "deviceId": deviceId || "",
            "load": -1,
            "temp": -1,
            "vramTemp": -1,
            "hasVram": false,
            "vramUsedGb": 0,
            "vramTotalGb": knownVram,
            "knownVramTotalGb": knownVram,
            "status": vendor === "nvidia" ? "offline" : "sensor",
            "powerW": -1,
            "energyUj": -1
        };
    }

    function cloneWith(base, patch) {
        var out = {};
        for (var k in base)
            out[k] = base[k];
        for (var p in patch)
            out[p] = patch[p];
        return out;
    }

    function syncLegacy() {
        hasGpu = gpus.length > 0;
        gpuVendor = hasGpu ? gpus[0].vendor : "none";
        amdDev = hasGpu && gpus[0].vendor === "amd" ? gpus[0].devPath : "";
        gpu = hasGpu && gpus[0].load >= 0 ? gpus[0].load : 0;
        gpuTemp = hasGpu ? gpus[0].temp : -1;

        var used = 0;
        var total = 0;
        var anyVram = false;
        for (var i = 0; i < gpus.length; i++) {
            var g = gpus[i];
            if (g.hasVram && g.vramTotalGb > 0) {
                anyVram = true;
                used += g.vramUsedGb;
                total += g.vramTotalGb;
            }
        }
        hasVram = anyVram;
        vramUsedGb = used;
        vramTotalGb = total;
    }

    function setDetectedGpus(next) {
        var merged = [];
        for (var i = 0; i < next.length; i++) {
            var incoming = next[i];
            var old = null;
            for (var j = 0; j < gpus.length; j++) {
                if (gpus[j].id === incoming.id) {
                    old = gpus[j];
                    break;
                }
            }
            merged.push(old ? cloneWith(incoming, {
                "load": old.load,
                "temp": old.temp,
                "vramTemp": old.vramTemp,
                "hasVram": old.hasVram,
                "vramUsedGb": old.vramUsedGb,
                "vramTotalGb": old.vramTotalGb,
                "status": old.status,
                "powerW": old.powerW,
                "energyUj": old.energyUj
            }) : incoming);
        }
        gpus = merged;
        gpuDevices = next;
        detected = true;
        syncLegacy();
    }

    function updateGpu(id, patch) {
        var next = gpus.slice();
        var idx = -1;
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                idx = i;
                break;
            }
        }

        if (idx < 0) return;
        var cur = next[idx];
        var merged = cloneWith(cur, patch);
        next[idx] = merged;
        gpus = next;
        syncLegacy();
    }

    Component.onCompleted: detectProc.running = true

    Process {
        id: detectProc
        command: ["timeout", "--kill-after=1s", "2s", "python3",
            decodeURIComponent(Qt.resolvedUrl("../scripts/gpu_stats.py").toString().replace(/^file:\/\//, "")), "discover"]
        stdout: StdioCollector { id: discoveryOutput }
        stderr: SplitParser {}
        onExited: (code) => {
            if (code !== 0) return;
            try {
                var result = JSON.parse(discoveryOutput.text);
                if (!result || !Array.isArray(result.devices)) return;
                root.tempPath = typeof result.tempPath === "string" ? result.tempPath : "";
                var next = [], seen = Object.create(null);
                result.devices.forEach(function(d) {
                    if (!d || !Gpu.pciAddress(d.pci) || seen[Gpu.pciAddress(d.pci)]
                            || ["intel", "nvidia", "amd"].indexOf(d.vendor) === -1) return;
                    d.pci = Gpu.pciAddress(d.pci);
                    seen[d.pci] = true;
                    var gpu = root.emptyGpu(d.pci, d.vendor, d.label, d.pci, d.devPath, d.deviceId);
                    gpu.nodes = Array.isArray(d.nodes) ? d.nodes : [];
                    gpu.hwmon = typeof d.hwmon === "string" ? d.hwmon : "";
                    next.push(gpu);
                });
                root.setDetectedGpus(next);
                if (root.open) root.primeAll();
            } catch (_) {}
        }
    }

    Instantiator {
        model: root.gpuDevices
        delegate: GpuCollector {
            required property var modelData
            device: modelData
            active: root.open
            onSampled: (id, patch) => root.updateGpu(id, patch)
        }
    }

    Process {
        id: fastProc
        command: ["sh", decodeURIComponent(Qt.resolvedUrl("../scripts/sysmon-fast.sh").toString().replace(/^file:\/\//, "")), root.tempPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "CPU") {
                        var total = parseFloat(p[1]);
                        var idle = parseFloat(p[2]);
                        if (root.prevCpuTotal > 0) {
                            var dt = total - root.prevCpuTotal;
                            var di = idle - root.prevCpuIdle;
                            root.cpu = dt > 0 ? Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt))) : 0;
                        }
                        root.prevCpuTotal = total;
                        root.prevCpuIdle = idle;
                    } else if (p[0] === "MEM") {
                        var mt = parseFloat(p[1]);
                        var ma = parseFloat(p[2]);
                        var st = parseFloat(p[3]);
                        var sf = parseFloat(p[4]);
                        root.memTotalGb = mt / 1048576;
                        root.memUsedGb = (mt - ma) / 1048576;
                        root.memPct = mt > 0 ? Math.round(100 * (mt - ma) / mt) : 0;
                        root.swapUsedGb = (st - sf) / 1048576;
                    } else if (p[0] === "NET") {
                        var rx = parseFloat(p[1]);
                        var tx = parseFloat(p[2]);
                        var now = Date.now();
                        var dtNet = (now - root.prevNetTime) / 1000;
                        if (root.prevNetTime > 0 && dtNet > 0) {
                            root.netDown = Math.max(0, (rx - root.prevRx) / dtNet / 1048576);
                            root.netUp = Math.max(0, (tx - root.prevTx) / dtNet / 1048576);
                        }
                        root.prevRx = rx;
                        root.prevTx = tx;
                        root.prevNetTime = now;
                    } else if (p[0] === "TMP") {
                        root.cpuTemp = p[1] === "-" ? -1 : Math.round(parseFloat(p[1]) / 1000);
                    }
                }
            }
        }
    }

    Process {
        id: slowProc
        command: ["sh", decodeURIComponent(Qt.resolvedUrl("../scripts/sysmon-slow.sh").toString().replace(/^file:\/\//, ""))]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "DISK")
                        root.diskPct = parseInt(p[1], 10) || 0;
                    else if (p[0] === "UP")
                        root.uptime = root.fmtUptime(parseInt(p[1], 10) || 0);
                }
            }
        }
    }

    Timer {
        interval: 500
        running: root.open
        repeat: true
        onTriggered: if (!fastProc.running) fastProc.running = true
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: if (!slowProc.running) slowProc.running = true
    }
}
