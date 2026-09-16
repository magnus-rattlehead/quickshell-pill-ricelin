import QtQuick
import Quickshell
import "@PILL@" as Pill

ShellRoot {
    id: root
    property double started: Date.now()
    function report(name, patch) { console.log("GPU_SAMPLE " + JSON.stringify({name:name,ms:Date.now()-started,load:patch.load,status:patch.status})); }
    function device(pci,vendor) { return {id:pci,pci:pci,vendor:vendor}; }
    Pill.GpuCollector {
        device: root.device("0000:01:00.0","nvidia")
        active: true
        sampleCommand: ["python3","@WORKER@","quickNvidia",device.pci,"0.02"]
        onSampled: (id, patch) => root.report("quickNvidia",patch)
    }
    Pill.GpuCollector {
        device: root.device("0000:02:00.0","intel")
        active: true
        sampleCommand: ["python3","@WORKER@","slowIntel",device.pci,"0.65"]
        onSampled: (id, patch) => root.report("slowIntel",patch)
    }
    Pill.GpuCollector {
        device: root.device("0000:03:00.0","intel")
        active: true
        sampleCommand: ["python3","@WORKER@","quickIntel",device.pci,"0.02"]
        onSampled: (id, patch) => root.report("quickIntel",patch)
    }
    Pill.GpuCollector {
        device: root.device("0000:04:00.0","nvidia")
        active: true
        sampleCommand: ["python3","@WORKER@","slowNvidia",device.pci,"0.65"]
        onSampled: (id, patch) => root.report("slowNvidia",patch)
    }
    Pill.GpuCollector {
        id: cancel
        device: root.device("0000:05:00.0","nvidia")
        active: true
        sampleCommand: ["python3","@WORKER@","cancel",device.pci,"0.5"]
        onSampled: (id, patch) => root.report("cancel",patch)
    }
    Pill.GpuCollector {
        id: hung
        device: root.device("0000:06:00.0","nvidia")
        active: true
        sampleCommand: ["python3","@WORKER@","hung",device.pci,"10"]
        onSampled: (id, patch) => { root.report("hung",patch); active=false; }
    }
    Timer { interval:150; running:true; onTriggered:cancel.active=false }
    Timer { interval:250; running:true; onTriggered:cancel.active=true }
    Timer { interval:3200; running:true; onTriggered:cancel.active=false }
    Timer { interval:4400; running:true; onTriggered:Qt.quit() }
}
