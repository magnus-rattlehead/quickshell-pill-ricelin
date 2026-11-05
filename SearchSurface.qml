pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

PillSurface {
    id: root
    topPadding: 15 * s; leftPadding: 17 * s; rightPadding: 17 * s; bottomPadding: 14 * s
    implicitWidth: 360 * s
    implicitHeight: 332 * s
    property var results: []
    property string emptyText: "No matches"
    property string counterText: ""
    readonly property string query: searchField.text
    property alias selectedIndex: resultsList.currentIndex
    property alias search: searchField
    property alias list: resultsList
    property alias divider: dividerLine
    property alias searchActions: rightSlot.data
    signal activated(var entry)
    signal searchKeyPressed(var event)

    onActiveChanged: if (active) {
        searchField.clear();
        resultsList.currentIndex = 0;
        Qt.callLater(function() { if (root.active) searchField.forceActiveFocus(); });
    }

    function activate() {
        var entry = results[selectedIndex];
        if (entry) activated(entry);
    }
    TextField {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30 * root.s
        padding: 0
        rightPadding: counter.implicitWidth + 10 * root.s + rightSlot.width + (rightSlot.width > 0 ? 10 * root.s : 0)
        color: Theme.text
        font.pixelSize: 15 * root.s
        placeholderTextColor: Theme.mid
        selectByMouse: true
        selectionColor: Theme.highlight
        selectedTextColor: Theme.window
        onTextChanged: resultsList.currentIndex = 0
        onAccepted: root.activate()
        Keys.forwardTo: [resultsList]
        Keys.onPressed: (event) => {
            root.searchKeyPressed(event);
            if (!event.accepted && (event.key === Qt.Key_Escape
                || (event.key === Qt.Key_Backspace && text.length === 0))) {
                root.requestClose();
                event.accepted = true;
            }
        }
        background: Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: searchField.leftPadding
                anchors.rightMargin: searchField.rightPadding
                height: 1
                color: Theme.accent
                opacity: searchField.activeFocus ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }
        PanelLabel {
            id: counter
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: rightSlot.left
            anchors.rightMargin: rightSlot.width > 0 ? 10 * root.s : 0
            text: root.counterText
            color: Theme.mid
            font.pixelSize: 10.5 * root.s
            font.features: { "tnum": 1 }
        }
        Item {
            id: rightSlot
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: childrenRect.width
            height: parent.height
        }
    }
    Rectangle {
        id: dividerLine
        anchors.top: searchField.bottom
        anchors.topMargin: 8 * root.s
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.text, 0.14)
    }
    SurfaceList {
        id: resultsList
        anchors.top: dividerLine.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        model: root.results
        property real s: root.s
        property point lastPointer: Qt.point(-1, -1)
        signal activated()
        keyNavigationEnabled: true
        currentIndex: 0
        onCountChanged: currentIndex = Math.max(0, Math.min(currentIndex, count - 1))
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        function selectAt(index, point) {
            if (point.x !== lastPointer.x || point.y !== lastPointer.y) {
                lastPointer = point;
                currentIndex = index;
            }
        }
        onActivated: root.activate()
        PanelLabel {
            anchors.centerIn: parent
            visible: resultsList.count === 0
            text: root.emptyText
            color: Theme.mid
            font.pixelSize: 10.5 * root.s
        }
        onBackgroundClicked: root.requestClose()
    }
}
