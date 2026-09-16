pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "lib/gpu.js" as Gpu

Item {
    id: root
    visible: false
    required property var device
    property bool active: false
    // Kept separate for fixture tests; production commands never pass through a shell.
    property list<string> sampleCommand: ["python3",
        decodeURIComponent(Qt.resolvedUrl("scripts/gpu_stats.py").toString().replace(/^file:\/\//, "")),
        "sample", JSON.stringify(device)]
    signal sampled(string id, var patch)

    property bool initialized: false
    property int generation: 0
    property bool warmupNeeded: true
    property var previous: null

    function sample() {
        if (!initialized || !active || worker.running) return;
        worker.generation = generation;
        worker.command = ["timeout", "--kill-after=1s", "2s"].concat(sampleCommand);
        worker.running = true;
    }
    function reset() {
        generation++;
        previous = null;
        warmupNeeded = true;
        warmup.stop();
        if (worker.running) worker.signal(15);
        else sample();
    }
    onActiveChanged: if (initialized) reset()
    Component.onCompleted: { initialized = true; reset(); }
    Component.onDestruction: if (worker.running) worker.signal(15)

    Timer {
        interval: 1000
        repeat: true
        running: root.initialized && root.active
        onTriggered: root.sample()
    }
    Timer { id: warmup; interval: 200; onTriggered: root.sample() }
    Process {
        id: worker
        property int generation: -1
        stdout: StdioCollector { id: output }
        stderr: SplitParser {}
        onExited: (code) => {
            if (generation !== root.generation) {
                Qt.callLater(root.sample);
                return;
            }
            if (!root.active) return;
            var result = code === 0 ? Gpu.sampleResult(output.text, root.device, root.previous) : null;
            root.previous = result ? result.state : null;
            root.sampled(root.device.id, result ? result.patch : Gpu.unavailable(root.device));
            if (!result) {
                root.warmupNeeded = true;
            } else if (root.warmupNeeded && root.device.vendor === "intel") {
                root.warmupNeeded = false;
                warmup.restart();
            }
        }
    }
}
