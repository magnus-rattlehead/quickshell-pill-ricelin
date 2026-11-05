pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Singleton {
    id: root

    // Ignore playerctld's proxy so each application appears once.
    readonly property var list: Mpris.players.values.filter(
        p => !p.dbusName.toLowerCase().includes("playerctld"))
    property var manualActive: null
    onListChanged: if (!list.includes(manualActive)) manualActive = null
    readonly property var active: manualActive
        || list.find(p => p.isPlaying) || list[0] || null

    function select(p) { manualActive = list.includes(p) ? p : null; }

    readonly property bool has: active !== null
    readonly property bool playing: has && active.isPlaying

    readonly property string title: has ? (active.trackTitle || labelOf(active)) : ""
    readonly property string artist: has ? active.trackArtist : ""
    readonly property string artUrl: has ? active.trackArtUrl : ""
    readonly property real lengthSec: has && active.lengthSupported
        && Number.isFinite(active.length) && active.length > 0 ? active.length : 0
    readonly property bool durationKnown: lengthSec > 0
    readonly property string serviceLabel: labelOf(active)

    readonly property string trackKey: has ? active.dbusName + "|" + active.uniqueId : ""

    function labelOf(p) {
        return p ? (p.identity || p.desktopEntry || "Media player") : "";
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "mediaToggle"
        description: "Play or pause the active media player"
        onPressed: { var a = root.active; if (a && a.canTogglePlaying) a.togglePlaying(); }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaNext"
        description: "Skip to the next track"
        onPressed: { var a = root.active; if (a && a.canGoNext) a.next(); }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaPrev"
        description: "Skip to the previous track"
        onPressed: { var a = root.active; if (a && a.canGoPrevious) a.previous(); }
    }
}
