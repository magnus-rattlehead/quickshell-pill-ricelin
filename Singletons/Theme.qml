pragma Singleton
import QtQuick

Palette {
    id: theme
    window: "#181818"
    windowText: theme.text
    base: "#222222"
    alternateBase: "#2c2c2c"
    text: "#ffffff"
    button: "#303030"
    buttonText: theme.text
    brightText: theme.text
    light: "#cfcfcf"
    midlight: "#404040"
    mid: "#888888"
    dark: "#606060"
    shadow: "#101010"
    highlight: "#bebebe"
    highlightedText: theme.window
    placeholderText: "#a6a6a6"
    accent: "#e0e0e0"
    disabled {
        text: "#777777"
        windowText: theme.disabled.text
        buttonText: theme.disabled.text
        brightText: theme.disabled.text
        placeholderText: "#666666"
        highlight: "#606060"
    }
}
