pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import "lib/glitch.js" as Glitch


Rectangle {
    id: toggle

    property real s: 1
    property bool on: false
    property bool focused: false
    signal toggled()

    width: 28 * s
    height: 16 * s
    radius: 4 * s
    color: on ? Theme.verm : Theme.tileBg
    border.width: focused ? 1 : (on ? 0 : 1)
    border.color: focused ? Qt.alpha(Theme.vermLit, 0.9) : Theme.border

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 10 * toggle.s
        height: 10 * toggle.s
        radius: width / 2
        color: Theme.cream
        x: toggle.on ? toggle.width - width - 3 * toggle.s : 3 * toggle.s
        Behavior on x { NumberAnimation { duration: Motion.fast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: Glitch.hover(toggle)
        onClicked: { Glitch.click(toggle); toggle.toggled(); }
    }
}
