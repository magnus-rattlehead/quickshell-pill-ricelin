pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Singletons"

ItemDelegate {
    id: setting
    property real s: 1
    property string glyph: ""
    property color glyphColor: Theme.text
    property string subtitle: ""
    property string detail: ""
    property real titleSize: 11
    property real subtitleSize: 9
    property bool toggleVisible: false
    property bool showChevron: false
    signal switchRequested()

    height: 48 * s
    padding: 6 * s
    hoverEnabled: true
    background: Rectangle {
        radius: 4 * setting.s
        color: setting.hovered ? Theme.base : "transparent"
        border.width: setting.hovered || setting.highlighted || setting.visualFocus ? 1 : 0
        border.color: setting.highlighted || setting.visualFocus ? Theme.accent : Theme.midlight
    }
    contentItem: RowLayout {
        spacing: 9 * setting.s
        GlyphIcon {
            visible: setting.glyph.length > 0
            Layout.preferredWidth: 17 * setting.s
            Layout.preferredHeight: 17 * setting.s
            name: setting.glyph
            color: setting.glyphColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * setting.s
            PanelLabel {
                Layout.fillWidth: true
                text: setting.text
                font.pixelSize: setting.titleSize * setting.s
                elide: Text.ElideRight
            }
            PanelLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: setting.subtitle
                font.pixelSize: setting.subtitleSize * setting.s
                color: Theme.placeholderText
                elide: Text.ElideRight
            }
        }
        PanelLabel {
            visible: text.length > 0
            text: setting.detail
            font.pixelSize: 8 * setting.s
            color: Theme.placeholderText
        }
        LinkToggle {
            s: setting.s
            visible: setting.toggleVisible
            checked: setting.checked
            onToggled: setting.switchRequested()
        }
        GlyphIcon {
            visible: setting.showChevron
            Layout.preferredWidth: 14 * setting.s
            Layout.preferredHeight: 14 * setting.s
            name: "chevron_right"
            color: Theme.highlight
        }
    }
}
