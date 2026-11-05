import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

Switch {
    id: control
    property real s: 1
    padding: 0
    implicitWidth: 28 * s
    implicitHeight: 16 * s
    indicator: Rectangle {
        width: control.width
        height: control.height
        radius: 4 * control.s
        color: control.checked ? Theme.highlight : Theme.base
        border.color: control.visualFocus ? Theme.text : Theme.midlight
        Rectangle {
            width: 10 * control.s
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - 3 * control.s : 3 * control.s
            color: Theme.text
            Behavior on x { NumberAnimation { duration: Motion.fast } }
        }
    }
}
