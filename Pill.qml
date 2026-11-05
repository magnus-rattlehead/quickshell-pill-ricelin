pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import "Singletons"

Control {
    id: pill
    palette: Theme
    font.family: Flags.uiFont || Config.font
    font.pixelSize: 10 * s

    property real s: 1
    property var hyprMonitor: null
    property string surface: ""

    property bool mainHovered: false
    property bool pinned: false

    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool expanded: surfaceOpen || pinned || mainHovered

    readonly property bool toastActive: Notifs.popup !== null && !surfaceOpen && !pinned
    readonly property string page: Config.pages[surface] || ""
    readonly property PillSurface currentPage: pageLoader.item as PillSurface

    signal requestSurface(string name)
    signal requestClose()
    signal togglePinned()

    function linkBack() {
        var link = pageLoader.item as Link;
        return link ? link.back() : false;
    }

    MouseArea {
        anchors.fill: parent
        enabled: pill.surfaceOpen
        onClicked: pill.requestClose()
    }

    TapHandler {
        enabled: !pill.surfaceOpen && !pill.toastActive
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.togglePinned()
    }

    QtObject {
        id: clock
        readonly property var loc: Qt.locale(Config.locale)
        readonly property var now: sysClock.date
        readonly property string hhmm: Qt.formatTime(now, Flags.clockSeconds ? Config.timeFormatSeconds : Config.timeFormat)
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property real restW: Math.max(160 * s, restClock.implicitWidth + 36 * s)
    readonly property real restH: 38 * s
    readonly property real hoverW: hoverRow.implicitWidth + 40 * s
    readonly property real hoverH: 58 * s
    readonly property real toastW: 342 * s

    readonly property size targetSize: {
        if (currentPage)
            return Qt.size(currentPage.implicitWidth, currentPage.implicitHeight);
        if (toastActive) {
            var card = toastLoader.item as NotificationCard;
            return Qt.size(toastW, card ? card.implicitHeight : 64 * s);
        }
        if (expanded)
            return Qt.size(Math.max(restW, hoverW), hoverH);
        return Qt.size(restW, restH);
    }

    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    width: targetW
    height: targetH

    Behavior on width { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    Rectangle {
        anchors.fill: parent
        visible: !pill.toastActive
        radius: (pill.surfaceOpen ? 12 : 10) * pill.s
        color: Qt.alpha(Theme.window, Flags.pillOpacity)
        border.width: 1
        border.color: Theme.midlight
    }

    component PillIcon: PanelButton {
        s: pill.s
        width: 22 * pill.s
        height: 22 * pill.s
        padding: 3 * pill.s
        enabled: hover.live
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (!pill.expanded && !pill.surfaceOpen && !pill.toastActive) ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        PanelLabel {
            id: restClock
            anchors.centerIn: parent
            text: clock.hhmm
            font.pixelSize: 16 * pill.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        opacity: live ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        readonly property bool live: pill.expanded && !pill.surfaceOpen && !pill.toastActive

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 18 * pill.s

            Workspaces {
                id: workspaceModule
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                hyprMonitor: pill.hyprMonitor
                s: pill.s
                gap: 8 * pill.s
                enabled: hover.live
            }

            Rectangle {
                visible: workspaceModule.hasMultipleWorkspaces
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Qt.alpha(Theme.text, 0.14)
            }

            PanelButton {
                anchors.verticalCenter: parent.verticalCenter
                s: pill.s
                enabled: hover.live
                padding: 5 * pill.s
                horizontalPadding: 11 * pill.s
                implicitHeight: implicitContentHeight + topPadding + bottomPadding
                onClicked: pill.requestSurface("calendar")
                contentItem: Column {
                    spacing: 2 * pill.s
                    PanelLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    PanelLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: Theme.placeholderText
                        font.pixelSize: 8.5 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2 * pill.s
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Qt.alpha(Theme.text, 0.14)
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * pill.s

                PanelButton {
                    id: wifiButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * pill.s; height: width
                    s: pill.s; padding: 2.5 * pill.s
                    enabled: hover.live
                    tip: "Network & Bluetooth"
                    onClicked: pill.requestSurface("link")
                    contentItem: WifiGlyph {
                        s: pill.s
                        level: NetworkState.activeNetwork ? NetworkState.activeNetwork.signalStrength : 0
                        on: NetworkState.wifiEnabled
                        litColor: wifiButton.hovered ? Theme.text : Theme.highlight
                    }
                }

                PillIcon {
                    glyph: "notifications"
                    tip: "Notifications"
                    onClicked: pill.requestSurface("notifications")
                }

                PillIcon {
                    glyph: "graphic_eq"
                    tip: "Mixer"
                    onClicked: { pill.requestSurface("mixer"); }
                }

                PillIcon {
                    glyph: "browse_activity"
                    tip: "System"
                    onClicked: { pill.requestSurface("sysmon"); }
                }

                PillIcon {
                    glyph: "music_note"
                    tip: "Media"
                    visible: Players.list.length > 0
                    onClicked: { pill.requestSurface("media"); }
                }

                PillIcon {
                    glyph: "power_settings_new"
                    tip: "Power"
                    onClicked: { pill.requestSurface("power"); }
                }
            }
        }
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        source: pill.page
        onLoaded: {
            var page = item as PillSurface;
            page.s = Qt.binding(() => pill.s);
            page.active = Qt.binding(() => pill.surfaceOpen);
            page.requestClose.connect(pill.requestClose);
        }
    }

    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        opacity: active ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        sourceComponent: NotificationCard {
            s: pill.s
            backgroundColor: Qt.alpha(Theme.window, Flags.pillOpacity)
            notif: Notifs.popup
            expanded: Notifs.popupExpanded
            onClicked: Notifs.popupExpanded = !Notifs.popupExpanded
        }
    }
}
