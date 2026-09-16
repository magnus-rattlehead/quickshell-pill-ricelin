pragma Singleton
import QtQuick
import Quickshell


Singleton {
    readonly property bool dyn: false

    readonly property color accent: Flags.accentColor


    // Cyberdream dark, matching the user's Ghostty palette.
    readonly property color bg: "#16181a"
    readonly property color bgAlt: "#1e2124"
    readonly property color bgHighlight: "#3c4048"
    readonly property color grey: "#7b8496"
    readonly property color blue: "#5ea1ff"
    readonly property color green: "#5eff6c"
    readonly property color cyan: "#5ef1ff"
    readonly property color red: "#ff6e5e"
    readonly property color yellow: "#f1ff5e"
    readonly property color purple: "#bd5eff"
    readonly property color onGlow: accent

    readonly property color verm:     Qt.darker(accent, 1.18)
    readonly property color vermLit:  accent
    readonly property color vermDeep: Qt.darker(accent, 1.8)
    readonly property color cream:    "#ffffff"
    readonly property color bright:   "#ffffff"
    readonly property color dim:      Qt.tint(grey, Qt.alpha(cream, 0.25))
    readonly property color cardTop:  bg
    readonly property color cardBot:  bg
    readonly property color border:   bgHighlight
    readonly property color shadow:   "#bb000000"
    readonly property color tileBg:   bgAlt
    readonly property color subtle:   Qt.tint(grey, Qt.alpha(cream, 0.60))
    readonly property color faint:    grey
    readonly property color iconDim:  Qt.tint(grey, Qt.alpha(cream, 0.45))
    readonly property color hair:     Qt.alpha(cream, 0.14)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen:    Qt.alpha(cream, 0.12)
    readonly property color vermDim:   Qt.darker(accent, 1.5)
    readonly property color vermDimDeep: Qt.darker(accent, 2.2)
    readonly property color vermBurn:  Qt.darker(vermDeep, 1.1)
    readonly property color tickRest:  grey
    readonly property color threadBg:  Qt.alpha(cream, 0.12)
    readonly property color flameCore: Qt.lighter(onGlow, 1.03)
    readonly property color flameGlow: onGlow


    readonly property string flameInk:   rgbHex(accent)
    readonly property string flameEmber: rgbHex(vermDeep)
    readonly property string flameBurn:  rgbHex(vermBurn)
    readonly property string flameTip:   rgbHex(Qt.lighter(accent, 1.25))
    readonly property color todayWarm: onGlow
    readonly property color ghost:     bgHighlight
    readonly property color frameBg:      Qt.alpha(bgHighlight, 0.65)
    readonly property color frameBorder:  Qt.alpha(grey, 0.45)
    readonly property color creamMenu:     Qt.alpha(cream, 0.84)
    readonly property real pillOpacity: 1.0
    readonly property real shadowOpacity: 0.52
    readonly property var fontFamilies: Qt.fontFamilies()
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Fira Code"
    readonly property string fontJp: "Zen Kaku Gothic New"

    function hexByte(value) {
        const hex = Math.round(value * 255).toString(16);
        return hex.length === 1 ? "0" + hex : hex;
    }

    function rgbHex(value) {
        return "#" + hexByte(value.r) + hexByte(value.g) + hexByte(value.b);
    }


    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
