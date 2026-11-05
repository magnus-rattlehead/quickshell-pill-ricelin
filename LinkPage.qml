pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

Item {
    id: page
    property real s: 1
    property bool active: false
    property string emptyText: ""
    property alias header: headerRow
    property alias list: items
    signal back()
    signal requestClose()
    implicitHeight: headerRow.height + 10 * s + Math.max(42 * s, items.height)

    SectionHeader {
        id: headerRow
        width: parent.width
        s: page.s
        titleColor: Theme.text
        showBack: true
        onBack: page.back()
    }
    SurfaceList {
        id: items
        anchors.top: headerRow.bottom
        anchors.topMargin: 10 * page.s
        width: parent.width
        height: Math.min(contentHeight, 280 * page.s)
        spacing: 4 * page.s
        onBackgroundClicked: page.requestClose()
    }
    PanelLabel {
        anchors.top: headerRow.bottom
        anchors.topMargin: 18 * page.s
        width: parent.width
        visible: items.count === 0
        text: page.emptyText
        color: Theme.placeholderText
        font.pixelSize: 11 * page.s
        horizontalAlignment: Text.AlignHCenter
    }
}
