pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false

    property int cpu: 0
    property int cpuTemp: -1

    property var gpus: []

    property real memUsedGb: 0
    property real memTotalGb: 0
    property int memPct: 0
    property real swapUsedGb: 0

    property real netDown: 0
    property real netUp: 0

    property var disks: []
    property string uptime: ""

    property real prevCpuTotal: 0
    property real prevCpuIdle: 0
    property real prevRx: 0
    property real prevTx: 0
    property real prevNetTime: 0

    function primeAll() {
        prevCpuTotal = 0;
        prevRx = 0;
        prevNetTime = 0;
        sampleFast();
        sampleSlow();
        if (!sensorsProc.running) sensorsProc.running = true;
    }

    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var hh = h < 10 ? "0" + h : "" + h;
        var mm = m < 10 ? "0" + m : "" + m;
        return "UP " + d + "D " + hh + ":" + mm;
    }

    function sampleGpus() {
        if (!gpuProc.running) gpuProc.running = true;
    }

    onOpenChanged: {
        gpuGeneration++;
        if (open) {
            primeAll();
            sampleGpus();
        } else if (gpuProc.running) {
            gpuProc.signal(15);
        }
    }

    property int gpuGeneration: 0
    Process {
        id: gpuProc
        property int generation: -1
        command: ["timeout", "--kill-after=1s", "2s", "nvtop", "--snapshot"]
        onStarted: generation = root.gpuGeneration
        stdout: StdioCollector { id: gpuOutput }
        stderr: SplitParser {}
        onExited: (code) => {
            if (generation !== root.gpuGeneration) {
                if (root.open) Qt.callLater(root.sampleGpus);
                return;
            }
            if (!root.open) return;
            var next = code === 0 ? root.gpuSnapshot(gpuOutput.text) : null;
            // Keep device labels visible on a failed sample, but clear old readings.
            root.gpus = next !== null ? next : root.gpus.map(root.unavailableGpu);
        }
    }

    Timer {
        interval: 1000
        running: root.open
        repeat: true
        onTriggered: root.sampleGpus()
    }

    Process {
        id: sensorsProc
        command: ["timeout", "--kill-after=1s", "2s", "sensors", "-j"]
        stdout: StdioCollector { id: sensorsOutput }
        stderr: SplitParser {}
        onExited: root.cpuTemp = root.cpuTemperature(sensorsOutput.text)
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        onTriggered: if (!sensorsProc.running) sensorsProc.running = true
    }

    // Read kernel counters directly; no shell or awk processes per sample.
    function sampleFast() {
        cpuFile.reload();
        memoryFile.reload();
        networkFile.reload();
    }

    function sampleSlow() {
        uptimeFile.reload();
        if (!diskProc.running) diskProc.running = true;
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            var fields = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            if (fields.length < 8 || fields.some(n => !isFinite(n))) return;
            var total = fields.reduce((sum, n) => sum + n, 0);
            var idle = fields[3] + fields[4];
            if (root.prevCpuTotal > 0) {
                var dt = total - root.prevCpuTotal;
                var di = idle - root.prevCpuIdle;
                root.cpu = dt > 0 ? Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt))) : 0;
            }
            root.prevCpuTotal = total;
            root.prevCpuIdle = idle;
        }
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            var values = {};
            text().split("\n").forEach(line => {
                var match = /^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/.exec(line);
                if (match) values[match[1]] = Number(match[2]);
            });
            if (!(values.MemTotal > 0) || values.MemAvailable === undefined) return;
            root.memTotalGb = values.MemTotal / 1048576;
            root.memUsedGb = (values.MemTotal - values.MemAvailable) / 1048576;
            root.memPct = Math.round(100 * (values.MemTotal - values.MemAvailable) / values.MemTotal);
            root.swapUsedGb = ((values.SwapTotal || 0) - (values.SwapFree || 0)) / 1048576;
        }
    }

    FileView {
        id: networkFile
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            var rx = 0, tx = 0;
            text().split("\n").slice(2).forEach(line => {
                var fields = line.trim().split(/[:\s]+/);
                if (fields.length < 10 || fields[0] === "lo") return;
                rx += Number(fields[1]) || 0;
                tx += Number(fields[9]) || 0;
            });
            var now = Date.now();
            var dt = (now - root.prevNetTime) / 1000;
            if (root.prevNetTime > 0 && dt > 0) {
                root.netDown = Math.max(0, (rx - root.prevRx) / dt / 1048576);
                root.netUp = Math.max(0, (tx - root.prevTx) / dt / 1048576);
            }
            root.prevRx = rx;
            root.prevTx = tx;
            root.prevNetTime = now;
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptime = root.fmtUptime(parseInt(text(), 10) || 0)
    }

    Process {
        id: diskProc
        command: ["env", "LC_ALL=C", "df", "-P", "-B1", "-l",
            "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Capture the mount point intact, including spaces in its name.
                root.disks = text.trim().split("\n").slice(1)
                    .map(line => /^(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(.+)$/.exec(line))
                    .filter(fields => fields !== null && Number(fields[2]) > 0)
                    .map(fields => ({device: fields[1], total: Number(fields[2]),
                        used: Number(fields[3]), percent: Number(fields[5]), mount: fields[6]}))
                    .sort((a, b) => a.mount.localeCompare(b.mount));
            }
        }
    }

    Timer {
        interval: 500
        running: root.open
        repeat: true
        onTriggered: root.sampleFast()
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: root.sampleSlow()
    }

    // NVTOP snapshots contain display units and memory sizes in bytes.
    function reading(value, unit, max) {
        if (typeof value !== "string" || !value.endsWith(unit)) return -1;
        var raw = value.slice(0, value.length - unit.length);
        if (!/^\d+(?:\.\d+)?$/.test(raw)) return -1;
        var number = Number(raw);
        return isFinite(number) && number <= max ? number : -1;
    }

    function unavailableGpu(device) {
        return { shortLabel: device.shortLabel, load: -1, temp: -1,
            hasVram: false, vramUsedGb: 0, vramTotalGb: 0 };
    }

    function gpuSnapshot(text) {
        var devices;
        try { devices = JSON.parse(text); } catch (_) { return null; }
        if (!Array.isArray(devices)) return null;
        var result = [];
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i];
            if (!d || typeof d.device_name !== "string" || !d.device_name.trim()) return null;
            var name = d.device_name.trim();
            var gpu = unavailableGpu({ shortLabel: name });
            gpu.load = reading(d.gpu_util, "%", 100);
            gpu.temp = reading(d.temp, "C", 200);
            var total = reading(d.mem_total, "", Number.MAX_SAFE_INTEGER);
            var used = reading(d.mem_used, "", Number.MAX_SAFE_INTEGER);
            if (total > 0 && used >= 0 && used <= total) {
                gpu.hasVram = true;
                gpu.vramUsedGb = used / 1073741824;
                gpu.vramTotalGb = total / 1073741824;
            }
            result.push(gpu);
        }
        return result;
    }

    function cpuTemperature(text) {
        var chips;
        try { chips = JSON.parse(text); } catch (_) { return -1; }
        if (!chips || typeof chips !== "object" || Array.isArray(chips)) return -1;
        var labels = ["Tdie", "Package id 0", "Tctl", "temp1"];
        for (var i = 0; i < labels.length; i++) {
            for (var chip in chips) {
                if (!/^(k10temp|coretemp|zenpower|cpu_thermal|acpitz)[-]/.test(chip)) continue;
                var sensor = chips[chip] && chips[chip][labels[i]];
                if (!sensor || typeof sensor !== "object") continue;
                for (var key in sensor) {
                    var value = sensor[key];
                    if (/^temp\d+_input$/.test(key) && typeof value === "number"
                            && isFinite(value) && value >= 0 && value <= 200)
                        return Math.round(value);
                }
            }
        }
        return -1;
    }
}
