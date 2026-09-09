pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Singletons"


PillSurface {
    id: root

    mTop: 15
    mLeft: 17
    mRight: 17
    mBottom: 14

    property string hovered: ""
    property int focusIndex: -1
    readonly property real anchorX: tiles.x + tiles.width / 2
    readonly property real anchorY: tiles.y - 10 * root.s
    property string soulKey: ""
    property real hoverX: 0
    property real hoverY: 0
    readonly property real heatX: soulKey.length ? hoverX : anchorX
    readonly property real heatY: soulKey.length ? hoverY : anchorY

    ameForm: soulKey.length ? "soul" : "off"
    amePoint: Qt.point(heatX, heatY)

    readonly property var actions: [
        { key: "lock",     glyph: "lock",     label: "Lock",     danger: false, dispatch: "",             argv: ["sh", "-c", "pidof hyprlock || loginctl lock-session"] },
        { key: "logout",   glyph: "logout",   label: "Logout",   danger: true,  dispatch: "hl.dsp.exit()", argv: [] },
        { key: "suspend",  glyph: "suspend",  label: "Sleep",    danger: false, dispatch: "",             argv: ["loginctl", "suspend"] },
        { key: "reboot",   glyph: "reboot",   label: "Restart",  danger: true,  dispatch: "",             argv: ["loginctl", "reboot"] },
        { key: "shutdown", glyph: "shutdown", label: "Shutdown", danger: true,  dispatch: "",             argv: ["loginctl", "poweroff"] }
    ]

    readonly property int splitAfter: 2

    component IconToggleChip: Rectangle {
        id: chip
        property string glyph: ""
        property bool on: false
        property string tipTitle: ""
        property string tipDesc: ""
        signal toggled()

        width: 26 * root.s
        height: 26 * root.s
        radius: 8 * root.s
        color: chip.on ? Theme.frameBg : "transparent"
        border.width: 1
        border.color: chip.on ? Theme.frameBorder : Theme.border

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: chip.glyph
            color: chip.on ? Theme.vermLit : Theme.iconDim
            stroke: 1.7
        }

        HoverHandler { id: chipHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: chip.tipTitle
            desc: chip.tipDesc
            show: chipHover.hovered
        }
    }

    function run(a) {
        if (a.dispatch && a.dispatch.length)
            Hyprland.dispatch(a.dispatch);
        else
            Quickshell.execDetached(a.argv);
        root.requestClose();
    }


    function move(dir) {
        if (focusIndex < 0)
            focusIndex = dir > 0 ? 0 : actions.length - 1;
        else
            focusIndex = Math.max(0, Math.min(actions.length - 1, focusIndex + dir));
    }


    function pressFocused() {
        if (focusIndex < 0 || focusIndex >= actions.length)
            return false;
        run(actions[focusIndex]);
        return true;
    }

    onActiveChanged: if (!active) {
        hovered = "";
        soulKey = "";
        focusIndex = -1;
    }

    Item {
        id: header
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                text: "電"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "POWER"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        IconToggleChip {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "awake"
            on: Flags.keepAwake
            tipTitle: "Keep awake"
            tipDesc: "Block sleep and screen-off"
            onToggled: Flags.keepAwake = !Flags.keepAwake
        }
    }

    Row {
        id: tiles
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: header.bottom
        anchors.topMargin: 14 * root.s
        spacing: 12 * root.s

        Repeater {
            model: root.actions

            delegate: Row {
                id: cell
                required property int index
                required property var modelData
                spacing: 12 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cell.index === root.splitAfter
                    width: 1
                    height: 26 * root.s
                    color: Theme.hair
                }

                Item {
                    id: tile
                    width: 50 * root.s
                    height: 50 * root.s

                    readonly property bool kbFocus: root.focusIndex === cell.index
                    readonly property bool isHover: root.hovered === cell.modelData.key || tile.kbFocus
                    readonly property bool lit: isHover
                    readonly property color accent: cell.modelData.danger ? Theme.vermLit : Theme.cream

                    onKbFocusChanged: {
                        if (!tile.kbFocus)
                            return;
                        root.hovered = cell.modelData.key;
                        root.soulKey = cell.modelData.key;
                        const c = tile.mapToItem(root, tile.width / 2, 0);
                        root.hoverX = c.x;
                        root.hoverY = c.y - 9 * root.s;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Motion.rTile * root.s
                        color: tile.isHover ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: tile.isHover ? Theme.frameBorder : Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 22 * root.s
                        height: 22 * root.s
                        name: cell.modelData.glyph
                        color: tile.lit ? tile.accent : Theme.iconDim
                        stroke: 1.9
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.hovered = cell.modelData.key;
                            root.soulKey = cell.modelData.key;
                            const c = tile.mapToItem(root, tile.width / 2, 0);
                            root.hoverX = c.x;
                            root.hoverY = c.y - 9 * root.s;
                        }
                        onExited: {
                            if (root.hovered === cell.modelData.key)
                                root.hovered = "";
                        }
                        onClicked: root.run(cell.modelData)
                    }
                }
            }
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: tiles.bottom
        anchors.topMargin: 12 * root.s
        readonly property string focusKey: root.hovered
        readonly property var act: {
            for (var i = 0; i < root.actions.length; i++)
                if (root.actions[i].key === label.focusKey)
                    return root.actions[i];
            return null;
        }
        text: act ? act.label : ""
        color: act && act.danger ? Theme.vermLit : Theme.subtle
        font.family: Theme.font
        font.pixelSize: 11 * root.s
        font.weight: Font.Medium
        font.letterSpacing: 0.4 * root.s
        opacity: text.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }
}
