import QtQuick
import "Singletons"

Rectangle {
    id: tile

    property bool depressed: false

    color: Theme.tileBg
    border.width: 1
    border.color: Theme.frameBorder

    // An inner dark bevel places the control below the surrounding surface.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, tile.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, tile.depressed ? 0.8 : 0.6) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, tile.depressed ? 0.4 : 0.15) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        x: tile.radius * 0.6
        y: tile.height - 2
        width: Math.max(0, tile.width - 2 * x)
        height: 1
        radius: 0.5
        color: Theme.sheen
        opacity: tile.depressed ? 0.2 : 0.6
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }
}
