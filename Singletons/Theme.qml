pragma Singleton
import QtQuick
import Quickshell


Singleton {
    readonly property bool dyn: false

    readonly property color accent: Flags.accentColor


    readonly property color onGlow: accent

    readonly property color verm:     Qt.darker(accent, 1.18)
    readonly property color vermLit:  accent
    readonly property color vermDeep: Qt.darker(accent, 1.8)
    readonly property color cream:    "#eeeeee"
    readonly property color bright:   "#ffffff"
    readonly property color dim:      "#a7a7a7"
    readonly property color cardTop:  "#101010"
    readonly property color cardBot:  "#101010"
    readonly property color border:   Qt.alpha(cream, 0.14)
    readonly property color shadow:   Qt.rgba(0, 0, 0, 0.58)
    readonly property color tileBg:   "#181818"
    readonly property color subtle:   "#d0d0d0"
    readonly property color faint:    "#777777"
    readonly property color iconDim:  "#b9b9b9"
    readonly property color hair:     Qt.alpha(cream, 0.14)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen:    Qt.alpha(cream, 0.05)
    readonly property color vermDim:   Qt.darker(accent, 1.5)
    readonly property color vermDimDeep: Qt.darker(accent, 2.2)
    readonly property color vermBurn:  Qt.darker(vermDeep, 1.1)
    readonly property color tickRest:  "#8a8a8a"
    readonly property color threadBg:  Qt.alpha(cream, 0.12)
    readonly property color flameCore: Qt.lighter(onGlow, 1.03)
    readonly property color flameGlow: onGlow


    readonly property string flameInk:   rgbHex(accent)
    readonly property string flameEmber: rgbHex(vermDeep)
    readonly property string flameBurn:  rgbHex(vermBurn)
    readonly property string flameTip:   rgbHex(Qt.lighter(accent, 1.25))
    readonly property color todayWarm: onGlow
    readonly property color ghost:     "#252525"
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.12)
    readonly property color creamMenu:     Qt.alpha(cream, 0.84)
    readonly property real pillOpacity: 1.0
    readonly property real shadowOpacity: 0.52
    readonly property var fontFamilies: Qt.fontFamilies()
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"
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
