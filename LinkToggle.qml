import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: control
    property real s: 1
    readonly property real toggleScale: s * 0.75
    padding: 0
    spacing: 0
    implicitWidth: indicator.implicitWidth * toggleScale
    implicitHeight: indicator.implicitHeight * toggleScale
    indicator.scale: control.toggleScale
}
