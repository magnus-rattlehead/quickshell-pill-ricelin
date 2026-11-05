pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Singletons"

RowLayout {
    id: header
    property real s: 1
    property string text: ""
    property color titleColor: Theme.light
    property bool showBack: false
    default property alias actions: actionRow.data
    signal back()

    height: 28 * s
    spacing: 4 * s
    PanelButton {
        s: header.s
        visible: header.showBack
        glyph: "chevron_left"
        tip: "Back"
        onClicked: header.back()
    }
    PanelLabel {
        Layout.fillWidth: true
        text: header.text
        color: header.titleColor
        font.pixelSize: 11 * header.s
        elide: Text.ElideRight
    }
    RowLayout {
        id: actionRow
        spacing: header.spacing
    }
}
