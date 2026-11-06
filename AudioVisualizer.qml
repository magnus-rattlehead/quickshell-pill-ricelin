pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

Item {
    id: root
    property bool active: false
    property real s: 1

    Loader {
        active: root.active
        sourceComponent: Component {
            QtObject {
                Component.onCompleted: Cava.subscribe()
                Component.onDestruction: Cava.unsubscribe()
            }
        }
    }

    AudioSpectrum {
        anchors.fill: parent
        values: root.active ? Cava.values : Array(Cava.barsCount).fill(0)
        fillColor: Theme.light
        minimumBarHeight: 2 * root.s
    }
}
