pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property int fast:     140
    readonly property int standard: 300
    readonly property int morph:    420
    readonly property int shapeshift: 820
    readonly property int glide:    260
    readonly property int heat:     1100
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline


    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property real rSmall: 4
    readonly property real rTile: 6


    readonly property int pulse: 420
}
