pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias clockSeconds: adapter.clockSeconds
    property alias uiScale: adapter.uiScale
    property alias uiFont: adapter.uiFont
    property alias pillOpacity: adapter.pillOpacity
    property alias topGap: adapter.topGap

    FileView {
        id: file
        path: Config.stateDir + "/flags.json"
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
            property bool dnd: false
            property bool keepAwake: false
            property bool clockSeconds: false

            property real uiScale: 1.0
            property string uiFont: ""
            property real pillOpacity: 1.0

            property real topGap: 1.0
        }
    }
}
