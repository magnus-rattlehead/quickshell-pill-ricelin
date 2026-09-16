pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland


Singleton {
    id: root

    property var byMonitor: Object.create(null)
    property var liveByMonitor: Object.create(null)
    property var activeByMonitor: Object.create(null)
    property int revision: 0
    property bool rulesPending: false
    property bool livePending: false
    property int startupRefreshes: 0

    readonly property var liveEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true,
        focusedmon: true, focusedmonv2: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    function refresh() {
        if (proc.running) {
            rulesPending = true;
            return;
        }
        proc.running = true;
    }

    function refreshLive() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        if (monProc.running || wsProc.running) {
            livePending = true;
            return;
        }
        monProc.running = true;
    }

    function bump() {
        revision = revision + 1;
    }

    function appendWorkspace(map, mon, id) {
        mon = mon ? String(mon) : "";
        id = parseInt(id);
        if (mon.length === 0 || isNaN(id) || id < 1)
            return;
        if (!map[mon])
            map[mon] = [];
        if (map[mon].indexOf(id) < 0)
            map[mon].push(id);
    }

    function sortMap(map) {
        for (var k in map)
            map[k].sort(function (a, b) { return a - b; });
        return map;
    }

    function applyMonitors(text) {
        var active = Object.create(null);
        try {
            var mons = JSON.parse(text);
            for (var i = 0; i < mons.length; i++) {
                var mon = mons[i];
                var name = mon.name ? String(mon.name) : "";
                if (name.length === 0)
                    continue;
                var ws = mon.activeWorkspace;
                if (ws && ws.name !== undefined)
                    active[name] = String(ws.name);
                else if (ws && ws.id !== undefined)
                    active[name] = String(ws.id);
            }
        } catch (e) {
            return;
        }
        activeByMonitor = active;
        bump();
    }

    function applyWorkspaces(text) {
        var map = Object.create(null);
        try {
            var wss = JSON.parse(text);
            for (var i = 0; i < wss.length; i++) {
                var ws = wss[i];
                appendWorkspace(map, ws.monitor, ws.id);
            }
            for (var mon in activeByMonitor)
                appendWorkspace(map, mon, activeByMonitor[mon]);
        } catch (e) {
            return;
        }
        liveByMonitor = sortMap(map);
        bump();
    }

    Process {
        id: proc
        command: ["hyprctl", "workspacerules", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = Object.create(null);
                try {
                    var rules = JSON.parse(this.text);
                    for (var i = 0; i < rules.length; i++) {
                        var ws = parseInt(rules[i].workspaceString);
                        var mon = rules[i].monitor;
                        if (!mon || isNaN(ws))
                            continue;
                        if (!map[mon])
                            map[mon] = [];
                        map[mon].push(ws);
                    }
                } catch (e) {
                    return;
                }
                for (var k in map)
                    map[k].sort(function (a, b) { return a - b; });
                root.byMonitor = map;
                root.bump();
            }
        }
        onExited: {
            if (root.rulesPending) {
                root.rulesPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.applyMonitors(this.text)
        }
        onExited: if (!wsProc.running) wsProc.running = true
    }

    Process {
        id: wsProc
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.applyWorkspaces(this.text)
        }
        onExited: {
            if (root.livePending) {
                root.livePending = false;
                Qt.callLater(root.refreshLive);
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.refresh();
            if (root.liveEvents[event.name])
                root.refreshLive();
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.startupRefreshes < 30
        onTriggered: {
            root.startupRefreshes = root.startupRefreshes + 1;
            root.refreshLive();
        }
    }

    Component.onCompleted: {
        refresh();
        refreshLive();
    }
}
