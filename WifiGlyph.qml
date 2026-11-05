import QtQuick

GlyphIcon {
    property real s: 1
    property real level: 0
    property bool on: true
    property color litColor: palette.highlight
    width: 17 * s
    height: 17 * s
    name: !on ? "wifi_off" : level > 0.66 ? "signal_wifi_4_bar"
        : level > 0.33 ? "network_wifi_2_bar" : level > 0 ? "network_wifi_1_bar" : "signal_wifi_0_bar"
    color: on ? litColor : palette.mid
}
