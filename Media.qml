pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Singletons"

PillSurface {
    id: root
    implicitWidth: (canPick ? 460 : 390) * s
    implicitHeight: 150 * s + Math.max(0, seek.implicitHeight - 18 * s)

    readonly property var player: Players.active

    readonly property bool positionKnown: !!player && player.positionSupported
    readonly property real positionSec: player && player.positionSupported ? Math.max(0, player.position) : 0
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

    onActiveChanged: if (active && player) player.positionChanged()

    FrameAnimation {
        running: root.active && Players.playing && root.positionKnown
        onTriggered: root.player.positionChanged()
    }

    component SkipButton: PanelButton {
        s: root.s
        width: 20 * root.s
        height: 24 * root.s
        padding: 2 * root.s
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 13 * root.s
    }

    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 118 * root.s
        AudioVisualizer {
            anchors.fill: parent
            anchors.margins: 16 * root.s
            s: root.s
            active: root.active && Players.playing
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
        anchors.bottomMargin: seek.height + 18 * root.s
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
            text: !Players.has ? "" : !Players.durationKnown
                ? " / Duration unavailable"
                : !root.positionKnown ? " / " + root.fmt(Players.lengthSec)
                : " / " + root.fmt(seek.pressed ? seek.position * Players.lengthSec : root.positionSec) + " - " + root.fmt(Players.lengthSec)
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
        anchors.bottomMargin: seek.height + 20 * root.s
        spacing: 14 * root.s

        SkipButton {
            glyph: "skip_previous"
            enabled: !!root.player && root.player.canGoPrevious
            onClicked: if (root.player) root.player.previous()
        }

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            width: 30 * root.s
            height: 30 * root.s
            enabled: !!root.player && root.player.canTogglePlaying
            glyph: Players.playing ? "pause" : "play_arrow"
            font.pixelSize: 16 * root.s
            onClicked: if (root.player) root.player.togglePlaying()
        }

        SkipButton {
            glyph: "skip_next"
            enabled: !!root.player && root.player.canGoNext
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
        height: Math.max(implicitHeight, 18 * root.s)
        from: 0; to: 1
        stepSize: Players.durationKnown ? 1 / Players.lengthSec : 0
        live: false
        visible: root.positionKnown && Players.durationKnown
        enabled: visible && !!root.player && root.player.canSeek
        property var dragPlayer: null
        property string dragTrack: ""
        // Suspend playback updates until the drag has been committed.
        Binding {
            target: seek
            property: "value"
            value: root.playFrac
            when: !seek.pressed && seek.dragPlayer === null
            restoreMode: Binding.RestoreNone
        }
        onPressedChanged: {
            if (pressed) { dragPlayer = root.player; dragTrack = Players.trackKey; }
            else {
                if (enabled && root.player === dragPlayer && Players.trackKey === dragTrack)
                    root.player.position = value * Players.lengthSec;
                dragPlayer = null;
                dragTrack = "";
            }
        }
        onMoved: if (!pressed && enabled) root.player.position = value * Players.lengthSec
    }
}
