pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell.Hyprland
import "Singletons"

Item {
    id: workspaces

    property var hyprMonitor: null
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s

    readonly property var openWorkspaces: Hyprland.workspaces.values.filter(w => !w.name.startsWith("special:")
        && (!w.monitor || w.monitor === hyprMonitor))
    readonly property bool hasMultipleWorkspaces: openWorkspaces.length > 1
    visible: hasMultipleWorkspaces

    readonly property var sortedWorkspaces: openWorkspaces.slice().sort((a, b) => {
        var left = Number(a.name), right = Number(b.name);
        return Number.isFinite(left) && Number.isFinite(right) ? left - right : a.name.localeCompare(b.name);
    })

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: workspaces.sortedWorkspaces

            delegate: Button {
                id: slot
                required property var modelData
                readonly property bool isActive: workspaces.hyprMonitor?.activeWorkspace === modelData
                Layout.preferredWidth: (isActive ? workspaces.stickW : workspaces.dotW) + workspaces.gap
                Layout.preferredHeight: 22 * workspaces.s
                horizontalPadding: workspaces.gap / 2
                verticalPadding: (height - workspaces.dotW) / 2
                hoverEnabled: true
                Accessible.name: "Workspace " + modelData.name
                onClicked: modelData.activate()
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                background: null
                contentItem: Rectangle {
                    radius: height / 2
                    color: slot.isActive ? Theme.accent : Theme.text
                    opacity: slot.isActive ? 1 : slot.hovered || slot.visualFocus ? 0.7 : 0.3
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }
            }
        }
    }
}
