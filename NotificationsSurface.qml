pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

PillSurface {
    id: root
    topPadding: 13 * s; leftPadding: 16 * s; rightPadding: 16 * s; bottomPadding: 13 * s
    implicitWidth: 330 * s
    contentItem.implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 6 * root.s
        SectionHeader {
            width: parent.width; s: root.s
            text: "Notifications · " + Notifs.count
            titleColor: Theme.placeholderText
            PanelButton {
                s: root.s; glyph: "notifications_off"; checked: Flags.dnd; tip: "Do not disturb"
                onClicked: Flags.dnd = !Flags.dnd
            }
            PanelButton {
                s: root.s; text: "Clear"; enabled: Notifs.count > 0
                onClicked: Notifs.clearAll()
            }
        }
        SurfaceList {
            id: notifications
            width: parent.width
            height: Math.min(contentHeight, 320 * root.s)
            spacing: 6 * root.s
            onBackgroundClicked: root.requestClose()
            model: Notifs.entries
            delegate: NotificationCard {
                required property var modelData
                width: notifications.width
                s: root.s; notif: modelData
                onClicked: expanded = !expanded
            }
        }
        PanelLabel {
            visible: Notifs.count === 0
            width: parent.width
            padding: 12 * root.s
            text: "No notifications"; horizontalAlignment: Text.AlignHCenter
            color: Theme.mid; font.pixelSize: 10 * root.s
        }
    }
}
