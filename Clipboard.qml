pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "Singletons"

SearchSurface {
    id: root
    results: {
        var needle = query.trim().toLowerCase();
        return Cliphist.entries.filter(entry => entry.preview.toLowerCase().includes(needle));
    }
    onActivated: (entry) => { Cliphist.copy(entry); root.requestClose(); }
    onActiveChanged: if (active) Cliphist.refresh()
    function removeAt(index) {
        if (index >= 0 && index < results.length) Cliphist.remove(results[index]);
    }
    search.placeholderText: "Search clipboard"
    counterText: results.length + " / " + Cliphist.count
    search.z: 5
    onSearchKeyPressed: (e) => {
        if (e.key === Qt.Key_X && (e.modifiers & Qt.ControlModifier)
            && root.search.selectedText.length === 0) {
            root.removeAt(root.selectedIndex);
            e.accepted = true;
        }
    }
    searchActions: Controls.DelayButton {
        id: wipeBtn
        anchors.verticalCenter: parent.verticalCenter
        width: 22 * root.s; height: width
        delay: 700
        padding: 4 * root.s
        onActivated: { Cliphist.wipe(); checked = false; }
        contentItem: GlyphIcon { name: "delete"; color: Theme.placeholderText }
        background: Rectangle { color: "transparent"; radius: 3 * root.s; border.color: Theme.midlight; border.width: wipeBtn.hovered ? 1 : 0 }
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.text: "Hold to wipe history"
    }
    divider.data: Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width * wipeBtn.progress
        visible: wipeBtn.progress > 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, 0.15) }
            GradientStop { position: 1.0; color: Theme.accent }
        }
    }
    emptyText: query.length ? "No matches" : "History empty"
    list.spacing: 2 * s
    list.delegate: ResultDelegate {
        id: row
        height: 28 * root.s
        readonly property var entry: root.results[index]
        contentItem: Item {
            anchors.fill: parent
            anchors.leftMargin: 11 * root.s
            anchors.rightMargin: 11 * root.s

            PanelLabel {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: tail.left
                anchors.rightMargin: 8 * root.s
                text: row.entry ? row.entry.preview : ""
                color: row.selected ? Theme.text : Theme.light
                font.pixelSize: 11.5 * root.s
                font.weight: row.selected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item {
                id: tail
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 22 * root.s
                height: width

                PanelLabel {
                    id: ret
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: row.selected && !row.hovered ? 1 : 0
                    text: "↵"
                    color: Theme.accent
                    font.pixelSize: 12 * root.s
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                PanelButton {
                    anchors.fill: parent
                    s: root.s; padding: 2 * root.s
                    text: "×"
                    tip: "Delete entry"
                    opacity: row.hovered ? 1 : 0
                    enabled: row.hovered
                    onClicked: root.removeAt(row.index)
                }
            }
        }
    }
}
