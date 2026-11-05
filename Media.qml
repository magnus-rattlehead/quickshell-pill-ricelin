pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Widgets
import "Singletons"

PillSurface {
    id: root
    implicitWidth: (canPick ? 460 : 390) * s
    implicitHeight: 150 * s

    readonly property var player: Players.active

    readonly property string coverSource: {
        if (!root.active)
            return "";
        var u = Players.artUrl;
        if (!u)
            return "";
        return u.indexOf("file:") === 0 ? u + "#" + Players.trackKey : u;
    }

    readonly property real positionSec: Players.has ? player.position : 0
    readonly property real playFrac: Players.lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / Players.lengthSec)) : 0

    readonly property bool canPick: Players.list.length > 1

    readonly property real textX: 134 * s
    readonly property real edgePad: 18 * s

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    Timer {
        interval: 500
        running: root.active && Players.playing && root.player.positionSupported
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    component SkipButton: PanelButton {
        s: root.s
        width: 20 * root.s
        height: 24 * root.s
        padding: 2 * root.s
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 13 * root.s
    }

    ClippingRectangle {
        radius: 11 * root.s
        color: "transparent"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 118 * root.s
        clip: true
        Image {
            id: cover
            anchors.fill: parent
            source: root.coverSource
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: String(source).indexOf("file:") !== 0
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: 40 * root.s; height: width
            name: "music_note"
            color: Theme.light
            visible: cover.status !== Image.Ready
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        anchors.right: parent.right
        anchors.rightMargin: root.edgePad
        anchors.top: parent.top
        anchors.topMargin: 24 * root.s
        spacing: 3 * root.s

        PanelLabel {
            id: titleLabel
            anchors.left: parent.left
            anchors.right: parent.right
            text: Players.title || "Nothing playing"
            font.pixelSize: 17 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            HoverHandler { id: titleHover }
            ToolTip.visible: titleHover.hovered && titleLabel.truncated
            ToolTip.text: text
        }
        PanelLabel {
            id: artistLabel
            anchors.left: parent.left
            anchors.right: parent.right
            text: Players.artist
            color: Theme.placeholderText
            font.pixelSize: 11.5 * root.s
            elide: Text.ElideRight
            HoverHandler { id: artistHover }
            ToolTip.visible: artistHover.hovered && artistLabel.truncated
            ToolTip.text: text
            visible: text.length > 0
        }
    }

    RowLayout {
        id: srcLine
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        anchors.right: transport.left
        anchors.rightMargin: 10 * root.s
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36 * root.s
        height: 34 * root.s
        spacing: 3 * root.s

        ComboBox {
            id: playerPicker
            visible: root.canPick
            Layout.maximumWidth: 120 * root.s
            Layout.preferredHeight: 24 * root.s
            model: Players.list
            currentIndex: Players.list.indexOf(root.player)
            displayText: Players.serviceLabel
            font.pixelSize: 10 * root.s
            palette.buttonText: Theme.text
            palette.text: Theme.text
            palette.window: Theme.base
            hoverEnabled: true
            onActivated: (index) => Players.select(model[index])
            background: Rectangle {
                radius: height / 2
                color: Qt.alpha(Theme.highlight, 0.16)
                border.width: 1
                border.color: Theme.midlight
            }
            popup.width: 260 * root.s
            delegate: SettingRow {
                required property var modelData
                width: playerPicker.popup.availableWidth
                height: 42 * root.s; s: root.s
                text: Players.labelOf(modelData)
                subtitle: modelData.trackTitle || ""
                highlighted: modelData === root.player
            }
            ToolTip.visible: hovered
            ToolTip.text: "Choose media player"
        }
        PanelLabel {
            visible: !root.canPick && text.length > 0
            text: Players.serviceLabel
            color: Theme.placeholderText
            font.pixelSize: 9.5 * root.s
        }
        PanelLabel {
            Layout.fillWidth: true
            text: !Players.has ? "" : Players.durationKnown
                ? " / " + root.fmt(seek.pressed ? seek.position * Players.lengthSec : root.positionSec) + " - " + root.fmt(Players.lengthSec)
                : " / " + root.fmt(root.positionSec)
            elide: Text.ElideRight
            color: Theme.placeholderText
            font.pixelSize: 9.5 * root.s
            font.features: { "tnum": 1 }
        }
    }

    Row {
        id: transport
        anchors.right: parent.right
        anchors.rightMargin: root.edgePad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38 * root.s
        spacing: 14 * root.s

        SkipButton {
            glyph: "skip_previous"
            enabled: Players.has && root.player.canGoPrevious
            onClicked: if (root.player) root.player.previous()
        }

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            width: 30 * root.s
            height: 30 * root.s
            enabled: Players.has && root.player.canTogglePlaying
            glyph: Players.playing ? "pause" : "play_arrow"
            font.pixelSize: 16 * root.s
            onClicked: if (root.player) root.player.togglePlaying()
        }

        SkipButton {
            glyph: "skip_next"
            enabled: Players.has && root.player.canGoNext
            onClicked: if (root.player) root.player.next()
        }
    }

    Slider {
        id: seek
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        anchors.right: parent.right
        anchors.rightMargin: root.edgePad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10 * root.s
        height: 18 * root.s
        from: 0; to: 1; stepSize: 0.01
        value: root.playFrac
        enabled: Players.has && root.player.canSeek && root.player.positionSupported && Players.durationKnown
        property var dragPlayer: null
        property string dragTrack: ""
        onPressedChanged: {
            if (pressed) { dragPlayer = root.player; dragTrack = Players.trackKey; }
            else if (enabled && root.player === dragPlayer && Players.trackKey === dragTrack)
                root.player.position = value * Players.lengthSec;
        }
        onMoved: if (!pressed && enabled) root.player.position = value * Players.lengthSec
        background: Rectangle {
            x: seek.leftPadding
            y: (seek.height - height) / 2
            width: seek.availableWidth
            height: 3 * root.s
            radius: height / 2
            color: Theme.midlight
            Rectangle { width: parent.width * seek.position; height: parent.height; radius: parent.radius; color: Theme.accent }
        }
        handle: Rectangle {
            x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
            y: (seek.height - height) / 2
            width: 7 * root.s; height: width; radius: width / 2
            color: seek.pressed || seek.visualFocus ? Theme.text : Theme.accent
        }
    }
}
