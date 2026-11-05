import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

ItemDelegate {
    id: row
    required property int index
    readonly property bool selected: ListView.isCurrentItem
    readonly property var results: ListView.view
    width: results.width
    padding: 0
    hoverEnabled: true
    onClicked: {
        results.currentIndex = index;
        results.activated();
    }
    HoverHandler {
        onPointChanged: if (hovered) row.results.selectAt(row.index, point.scenePosition)
    }
    background: Rectangle {
        radius: 4 * row.results.s
        color: "transparent"
        border.width: row.selected || row.hovered ? 1 : 0
        border.color: Theme.midlight
    }
}
