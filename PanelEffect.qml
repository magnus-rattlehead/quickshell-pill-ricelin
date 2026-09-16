pragma ComponentBehavior: Bound
import QtQuick

ShaderEffect {
    id: effect

    property var source
    property size panelSize: Qt.size(width, height)
    property real padding: 0
    property real pixelRatio: 1
    property real time: 0
    property real hoverStrength: 0
    property real clickStrength: 0
    readonly property size resolution: Qt.size(Math.max(1, panelSize.width * pixelRatio),
                                               Math.max(1, panelSize.height * pixelRatio))
    readonly property real paddingPx: padding * pixelRatio
    readonly property real motion: 0

    fragmentShader: Qt.resolvedUrl("shaders/interaction-glitch.frag.qsb")
    layer.enabled: true
    layer.smooth: true
    layer.effect: ShaderEffect {
        property var source
        readonly property size resolution: effect.resolution
        readonly property real paddingPx: effect.paddingPx
        readonly property real time: effect.time
        readonly property real motion: effect.motion
        fragmentShader: Qt.resolvedUrl("shaders/bloom.frag.qsb")
    }
}
