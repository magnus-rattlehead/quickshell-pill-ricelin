import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

Button {
    id: control
    property real s: 1
    property string glyph: ""
    property string tip: ""
    text: glyph
    padding: 6 * s
    horizontalPadding: padding
    implicitHeight: 28 * s
    implicitWidth: Math.max(28 * s, implicitContentWidth + leftPadding + rightPadding)
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    font.family: glyph.length ? IconFont.name : Qt.font({}).family
    font.pixelSize: (glyph.length ? 15 : 10) * s
    font.features: glyph.length ? { "liga": 1 } : {}
    palette.buttonText: Theme.text
    palette.brightText: Theme.text
    palette.windowText: Theme.text

    background: Rectangle {
        radius: 4 * control.s
        color: control.down || control.checked ? Theme.midlight : "transparent"
        border.width: control.hovered || control.visualFocus || control.checked ? 1 : 0
        border.color: Theme.midlight
    }
    ToolTip.visible: hovered && tip.length > 0
    ToolTip.text: tip
    ToolTip.delay: 470
}
