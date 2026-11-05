import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

Control {
    id: surface

    property real s: 1
    property bool active: false
    default property alias contentData: pageContent.data

    signal requestClose()

    data: MouseArea {
        anchors.fill: parent
        onClicked: surface.requestClose()
    }

    contentItem: Item { id: pageContent; z: 1 }

    anchors.fill: parent

    enabled: active
    opacity: active ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
}
