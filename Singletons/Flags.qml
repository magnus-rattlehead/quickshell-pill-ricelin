pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io


Singleton {
    id: root

    readonly property int appearanceVersion: 5

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias clockSeconds: adapter.clockSeconds
    property alias showGlyphs: adapter.showGlyphs
    property alias accentColor: adapter.accentColor
    property alias uiScale: adapter.uiScale
    property alias uiFont: adapter.uiFont
    property alias pillOpacity: adapter.pillOpacity
    property alias appearanceMigrated: adapter.appearanceMigrated
    property alias savedAppearanceVersion: adapter.appearanceVersion
    property alias topGap: adapter.topGap
    property alias weatherCity: adapter.weatherCity

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property int appearanceVersion: 0
            property bool appearanceMigrated: false
            property bool dnd: false
            property bool keepAwake: false
            property bool clockSeconds: false
            property bool showGlyphs: false

            property string accentColor: "#5ea1ff"

            property real uiScale: 1.0
            property string uiFont: ""
            property real pillOpacity: 1.0

            property real topGap: 1.0

            property string weatherCity: ""
        }
    }

    Component.onCompleted: {
        if (root.savedAppearanceVersion >= root.appearanceVersion)
            return;

        // Preserve opacity and custom accents when upgrading the theme.
        if (root.accentColor.toLowerCase() === "#ffffff"
                || root.accentColor.toLowerCase() === "white"
                || root.accentColor.toLowerCase() === "#b9a1cb"
                || (root.savedAppearanceVersion === 3 && root.accentColor.toLowerCase() === "#ff71ce"))
            root.accentColor = "#5ea1ff";
        root.appearanceMigrated = true;
        root.savedAppearanceVersion = root.appearanceVersion;
    }
}
