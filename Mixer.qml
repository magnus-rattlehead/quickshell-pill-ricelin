pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Services.Pipewire
import "Singletons"

PillSurface {
    id: root
    topPadding: 13 * s; leftPadding: 14 * s; rightPadding: 14 * s; bottomPadding: 16 * s
    implicitWidth: 124 * faderCount * s
    contentItem.implicitHeight: header.height + 10 * s + faders.implicitHeight
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property var outputSinks: Pipewire.nodes.values
        .filter(node => node.isSink && !node.isStream && node.audio)
        .sort((a, b) => deviceLabel(a).localeCompare(deviceLabel(b)))
    readonly property var inputSources: Pipewire.nodes.values
        .filter(node => !node.isSink && !node.isStream && node.audio && !/monitor/i.test(node.name))
        .sort((a, b) => deviceLabel(a).localeCompare(deviceLabel(b)))

    function deviceLabel(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "";
    }

    readonly property int faderCount: 2
    onActiveChanged: if (!active) { outputPicker.popup.close(); inputPicker.popup.close(); }
    PwObjectTracker { objects: [root.sink, root.source].concat(root.outputSinks, root.inputSources).filter(Boolean) }

    component DevicePicker: ComboBox {
        id: picker
        property var current: null
        property string glyph: ""
        property string tip: ""
        signal pick(var node)
        implicitWidth: 28 * root.s
        implicitHeight: 28 * root.s
        padding: 6 * root.s
        leftPadding: padding
        rightPadding: padding
        enabled: count > 0
        currentIndex: model.indexOf(current)
        displayText: glyph
        font.family: IconFont.name
        font.pixelSize: 15 * root.s
        font.features: { "liga": 1 }
        palette.buttonText: Theme.text
        palette.text: Theme.text
        palette.window: Theme.base
        palette.highlight: Theme.midlight
        palette.highlightedText: Theme.text
        indicator: null
        contentItem: Label {
            text: picker.displayText
            font: picker.font
            color: picker.palette.buttonText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        popup.width: 300 * root.s
        popup.height: Math.min(popup.implicitHeight, 180 * root.s)
        onActivated: (index) => pick(model[index])
        background: Rectangle {
            radius: 4 * root.s
            color: picker.down ? Theme.midlight : "transparent"
            border.width: picker.hovered || picker.visualFocus || picker.popup.visible ? 1 : 0
            border.color: Theme.midlight
        }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: picker.popup.availableWidth
            height: 28 * root.s
            text: root.deviceLabel(modelData)
            font.family: root.font.family
            font.pixelSize: 10 * root.s
            palette.text: Theme.text
            highlighted: picker.highlightedIndex === index
        }
        ToolTip.visible: hovered
        ToolTip.text: tip + (current ? " · " + root.deviceLabel(current) : "")
    }
    SectionHeader {
        id: header
        width: parent.width
        s: root.s
        text: "MIXER"
        DevicePicker {
            id: outputPicker
            model: root.outputSinks; current: root.sink
            glyph: "volume_up"; tip: "Output device"
            onPick: (node) => Pipewire.preferredDefaultAudioSink = node
        }
        DevicePicker {
            id: inputPicker
            model: root.inputSources; current: root.source
            glyph: "mic"; tip: "Input device"
            onPick: (node) => Pipewire.preferredDefaultAudioSource = node
        }
    }
    component AudioChannel: Column {
        id: channel
        required property var node
        required property string title
        required property string device
        required property string glyph
        required property string mutedGlyph
        property bool showOffWhenMuted: false
        readonly property var audio: node ? node.audio : null
        width: faders.width / root.faderCount
        Column {
            width: parent.width
            spacing: 5 * root.s
            Slider {
                id: slider
                anchors.horizontalCenter: parent.horizontalCenter
                width: 24 * root.s
                height: 86 * root.s
                from: 0; to: 1; stepSize: 0.01
                orientation: Qt.Vertical
                wheelEnabled: true
                value: channel.audio ? channel.audio.volume : 0
                onMoved: if (channel.audio) channel.audio.volume = value
                background: Rectangle {
                    x: (slider.width - width) / 2
                    y: slider.topPadding
                    width: 3 * root.s
                    height: slider.availableHeight
                    radius: width / 2
                    color: Qt.alpha(Theme.text, 0.12)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * slider.position
                        radius: parent.radius
                        color: Theme.accent
                    }
                }
                handle: Rectangle {
                    x: (slider.width - width) / 2
                    y: slider.topPadding + slider.visualPosition * (slider.availableHeight - height)
                    width: 11 * root.s
                    height: 5 * root.s
                    radius: root.s
                    color: slider.pressed || slider.visualFocus ? Theme.text : Theme.accent
                }
            }
            PanelLabel {
                id: valueText
                width: parent.width
                text: channel.showOffWhenMuted && channel.audio && channel.audio.muted ? "off" : Math.round(slider.value * 100) + "%"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 9 * root.s
            }
            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 16 * root.s; height: width
                name: channel.audio && channel.audio.muted ? channel.mutedGlyph : channel.glyph
            }
            // Keep the existing space above the mute button.
            Item { width: parent.width; height: valueText.implicitHeight }
        }
        PanelButton {
            anchors.horizontalCenter: parent.horizontalCenter
            s: root.s; text: channel.title
            enabled: !!channel.audio
            checked: enabled && channel.audio.muted
            tip: (checked ? "Unmute " : "Mute ") + channel.device
            onClicked: channel.audio.muted = !channel.audio.muted
        }
    }
    Row {
        id: faders
        anchors.top: header.bottom
        anchors.topMargin: 10 * root.s
        width: parent.width
        AudioChannel {
            node: root.sink; title: "Volume"; device: "output"
            glyph: "volume_up"; mutedGlyph: "volume_off"
        }
        AudioChannel {
            node: root.source; title: "Microphone"; device: "microphone"
            glyph: "mic"; mutedGlyph: "mic_off"; showOffWhenMuted: true
        }
    }
}
