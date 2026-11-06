pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Singletons"

PillSurface {
    id: root
    topPadding: 15 * s; leftPadding: 17 * s; rightPadding: 17 * s; bottomPadding: 14 * s
    implicitWidth: 330 * s
    contentItem.implicitHeight: header.height + 12 * s + actionRow.implicitHeight
    readonly property var actions: [
        { glyph: "lock", label: "Lock", argv: Config.lockCommand },
        { glyph: "logout", label: "Logout", argv: null },
        { glyph: "bedtime", label: "Sleep", argv: Config.suspendCommand },
        { glyph: "restart_alt", label: "Restart", argv: Config.rebootCommand },
        { glyph: "power_settings_new", label: "Shutdown", argv: Config.shutdownCommand }
    ]

    function run(action) {
        if (action.argv === null) Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit");
        else Quickshell.execDetached(action.argv);
        requestClose();
    }
    SectionHeader {
        id: header
        width: parent.width
        s: root.s
        text: "POWER"
        PanelButton {
            s: root.s; glyph: "visibility"; tip: "Keep awake · Prevent idle"
            checked: Flags.keepAwake
            onClicked: Flags.keepAwake = !Flags.keepAwake
        }
    }
    Row {
        id: actionRow
        anchors.top: header.bottom
        anchors.topMargin: 12 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6 * root.s
        Repeater {
            model: root.actions
            PanelButton {
                id: actionButton
                required property var modelData
                s: root.s
                width: 54 * root.s
                height: 58 * root.s
                enabled: modelData.argv === null || modelData.argv.length > 0
                tip: modelData.label
                onClicked: root.run(modelData)
                contentItem: Column {
                    spacing: 6 * root.s
                    GlyphIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22 * root.s; height: width
                        name: actionButton.modelData.glyph
                        color: Theme.text
                    }
                    PanelLabel {
                        width: parent.width
                        text: actionButton.modelData.label
                        color: Theme.placeholderText
                        font.pixelSize: 8 * root.s
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
