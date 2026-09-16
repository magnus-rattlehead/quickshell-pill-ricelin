pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "Singletons"
import "lib/glitch.js" as Glitch
import "lib/safe.js" as Safe


Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s

    function workspaceMonitorName(w) {
        if (w.monitor)
            return w.monitor.name !== undefined ? String(w.monitor.name) : String(w.monitor);

        var o = w.lastIpcObject;
        return o && o.monitor ? String(o.monitor) : "";
    }

    function monitorActiveWorkspaceName(mon) {
        if (mon.activeWorkspace)
            return mon.activeWorkspace.name !== undefined ? String(mon.activeWorkspace.name) : String(mon.activeWorkspace);

        var o = mon.lastIpcObject;
        if (o && o.activeWorkspace && o.activeWorkspace.name !== undefined)
            return String(o.activeWorkspace.name);
        return "";
    }

    function appendWorkspace(out, seen, id) {
        id = parseInt(id);
        if (id >= 1 && !seen[id]) {
            seen[id] = true;
            out.push(id);
        }
    }

    readonly property var range: {
        void Workspacerules.revision;

        var ruled = Workspacerules.byMonitor[screenName];
        if (ruled && ruled.length)
            return ruled;

        var out = [];
        var seen = Object.create(null);
        var live = Workspacerules.liveByMonitor[screenName];
        if (live) {
            for (var l = 0; l < live.length; l++)
                appendWorkspace(out, seen, live[l]);
        }

        var wss = Hyprland.workspaces.values;
        for (var i = 0; i < wss.length; i++) {
            var w = wss[i];
            if (workspaceMonitorName(w) === screenName)
                appendWorkspace(out, seen, w.id);
        }
        appendWorkspace(out, seen, activeName);
        out.sort(function (x, y) { return x - y; });
        return out;
    }

    readonly property string activeName: {
        void Workspacerules.revision;

        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === screenName) {
                var liveName = monitorActiveWorkspaceName(mons[i]);
                if (liveName.length > 0)
                    return liveName;
            }
        }
        var snapName = Workspacerules.activeByMonitor[screenName];
        if (snapName !== undefined && String(snapName).length > 0)
            return String(snapName);
        return "";
    }

    property int hoverIndex: -1

    readonly property int activeIndex: range.indexOf(parseInt(activeName))


    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData
                required property int index

                readonly property string wsName: String(modelData)
                readonly property bool isActive: workspaces.activeName === wsName

                Layout.preferredWidth: slot.isActive ? workspaces.stickW : workspaces.dotW
                Layout.preferredHeight: 22 * workspaces.s
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.containsMouse ? 0.7 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.leftMargin: -workspaces.gap / 2
                    anchors.rightMargin: -workspaces.gap / 2
                    anchors.topMargin: -8 * workspaces.s
                    anchors.bottomMargin: -8 * workspaces.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: Glitch.hover(workspaces)
                    onClicked: { Glitch.click(workspaces); if (Safe.workspaceId(slot.modelData)) Hyprland.dispatch('hl.dsp.focus({workspace="' + Safe.workspaceId(slot.modelData) + '"})'); }
                    onContainsMouseChanged: {
                        if (containsMouse)
                            workspaces.hoverIndex = slot.index;
                        else if (workspaces.hoverIndex === slot.index)
                            workspaces.hoverIndex = -1;
                    }
                }
            }
        }
    }
}
