import QtQuick
import "Singletons"


Item {
    id: surface

    property real s: 1
    property bool open: false
    property real morphCloseness: 1

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    signal requestClose()


    property string ameForm: "off"
    property point amePoint: Qt.point(width / 2, height / 2)

    readonly property bool active: open


    property bool settled: false
    onOpenChanged: if (!open) settled = false
    onMorphClosenessChanged: if (open && morphCloseness > 0.92) settled = true

    anchors.fill: parent
    anchors.topMargin: mTop * s
    anchors.leftMargin: mLeft * s
    anchors.rightMargin: mRight * s
    anchors.bottomMargin: mBottom * s

    enabled: open
    opacity: open ? (settled ? 1 : Math.pow(morphCloseness, 1.3)) : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
}
