pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []
    readonly property int count: entries.length
    property bool pending: false
    property var delQueue: []

    function refresh() {
        pending = listProc.running || delProc.running || wipeProc.running || delQueue.length > 0;
        if (!pending) listProc.running = true;
    }

    function copy(entry) {
        if (/^\d+$/.test(String(entry.id)))
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)]);
    }

    function wipe() {
        entries = [];
        delQueue = [];
        pending = true;
        wipeProc.running = true;
    }

    function remove(entry) {
        var id = String(entry.id);
        if (!/^\d+$/.test(id)) return;
        entries = entries.filter(e => e.id !== id);
        delQueue.push(id);
        pending = true;
        pumpDeletes();
    }

    function pumpDeletes() {
        if (delProc.running || !delQueue.length) return;
        delProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", delQueue.shift()];
        delProc.running = true;
    }

    Process {
        id: delProc
        onExited: {
            if (root.delQueue.length) root.pumpDeletes();
            else root.refresh();
        }
    }
    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector { id: output }
        onExited: (code) => {
            if (code === 0 && !root.pending) {
                root.entries = output.text.split("\n")
                    .map(line => /^(\d+)\t(.*)$/.exec(line))
                    .filter(match => match !== null)
                    .map(match => ({id: match[1], preview: match[2]}));
            }
            if (root.pending) Qt.callLater(root.refresh);
        }
    }
}
