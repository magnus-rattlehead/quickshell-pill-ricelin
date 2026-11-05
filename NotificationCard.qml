pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "Singletons"

ItemDelegate {
    id: card
    required property var notif
    property real s: 1
    property color backgroundColor: "transparent"
    property bool expanded: false
    readonly property var defaultAction: (notif.actions || []).find(a => a.identifier === "default") || null

    padding: 8 * s
    hoverEnabled: true
    background: Rectangle {
        radius: 4 * card.s
        color: card.backgroundColor
        border.color: card.notif.urgency === NotificationUrgency.Critical ? Theme.accent : Theme.midlight
        border.width: card.hovered || card.notif.urgency === NotificationUrgency.Critical ? 1 : 0
    }
    contentItem: ColumnLayout {
        spacing: 4 * card.s
        RowLayout {
            Layout.fillWidth: true
            spacing: 7 * card.s
            Image {
                Layout.preferredWidth: 22 * card.s
                Layout.preferredHeight: 22 * card.s
                source: Notifs.iconFor(card.notif)
                sourceSize: Qt.size(44, 44)
                fillMode: Image.PreserveAspectFit
            }
            PanelLabel {
                Layout.fillWidth: true
                text: card.notif.appName || "System"
                color: Theme.placeholderText
                font.pixelSize: 9 * card.s
                elide: Text.ElideRight
            }
            PanelButton {
                s: card.s; text: "×"; tip: "Dismiss"
                implicitWidth: 22 * card.s; implicitHeight: 22 * card.s; padding: 2 * card.s
                onClicked: card.notif.dismiss()
            }
        }
        PanelLabel {
            Layout.fillWidth: true
            text: card.notif.summary
            font.pixelSize: 11.5 * card.s
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: card.expanded ? 1000 : 1
            elide: Text.ElideRight
        }
        PanelLabel {
            Layout.fillWidth: true
            visible: text.length > 0
            text: card.notif.body
            color: Theme.placeholderText
            font.pixelSize: 10.5 * card.s
            wrapMode: Text.Wrap
            maximumLineCount: card.expanded ? 1000 : 2
            elide: Text.ElideRight
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4 * card.s
            PanelButton {
                s: card.s; text: "Open"
                visible: card.defaultAction !== null
                onClicked: card.defaultAction.invoke()
            }
            Repeater {
                model: (card.notif.actions || []).filter(a => a.identifier !== "default" && a.text.length > 0)
                PanelButton {
                    required property var modelData
                    s: card.s; text: modelData.text
                    width: Math.min(implicitWidth, parent.width)
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
