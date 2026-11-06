// Adapted from Noctalia v4.4.0 NMirroredSpectrum.qml (MIT).
// Copyright (c) 2025 noctalia-dev.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    property var values: []
    property color fillColor: "white"
    property real minimumBarHeight: 2

    readonly property int valuesCount: values.length
    readonly property int totalBars: valuesCount * 2
    readonly property real barSlotSize: totalBars > 0 ? width / totalBars : 0

    Repeater {
        model: root.totalBars

        Rectangle {
            required property int index
            readonly property int valueIndex: index < root.valuesCount
                ? root.valuesCount - 1 - index : index - root.valuesCount
            readonly property real amplitude: Math.max(0, Math.min(1, root.values[valueIndex] || 0))

            x: (index + 0.1) * root.barSlotSize
            y: (root.height - height) / 2
            width: root.barSlotSize * 0.8
            height: Math.max(root.minimumBarHeight, root.height * amplitude)
            radius: width / 2
            color: root.fillColor
            antialiasing: true

            Behavior on height {
                NumberAnimation { duration: 25; easing.type: Easing.OutCubic }
            }
        }
    }
}
