import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

Label {
    property string name: ""
    width: 24
    height: 24
    color: palette.highlight
    text: name
    textFormat: Text.PlainText
    font.family: IconFont.name
    font.pixelSize: Math.max(1, Math.round(Math.min(width, height)))
    font.features: { "liga": 1 }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    visible: IconFont.status === FontLoader.Ready
}
