import QtQuick
import "Singletons"


Item {
    id: root

    property string text: ""
    property color color: Theme.cream
    property real pixelSize: 14
    property int weight: Font.Normal
    property bool active: true

    property real scrollX: 0

    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool overflowing: label.implicitWidth > width

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(root.scrollX)
        text: root.text
        color: root.color
        renderType: Text.NativeRendering
        font.family: Theme.font
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        elide: root.overflowing ? Text.ElideNone : Text.ElideRight
        width: root.overflowing ? implicitWidth : root.width

        onTextChanged: root.sync()
    }

    SequentialAnimation {
        id: anim
        loops: Animation.Infinite
        PauseAnimation { duration: 1800 }
        NumberAnimation {
            target: root
            property: "scrollX"
            from: 0
            to: -(label.implicitWidth - root.width)
            duration: Math.max(1, label.implicitWidth - root.width) * 22
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 1800 }
        NumberAnimation {
            target: root
            property: "scrollX"
            from: -(label.implicitWidth - root.width)
            to: 0
            duration: Math.max(1, label.implicitWidth - root.width) * 22
            easing.type: Easing.InOutSine
        }
    }

    onActiveChanged: sync()
    onOverflowingChanged: sync()
    Component.onCompleted: sync()


    function sync() {
        anim.stop();
        root.scrollX = 0;
        if (overflowing && active)
            anim.start();
    }
}
