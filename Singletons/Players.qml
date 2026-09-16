pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland


Singleton {
    id: root

    function isProxy(p) {
        return (p && p.dbusName ? p.dbusName : "").toLowerCase().indexOf("playerctld") >= 0;
    }

    function isIdle(p) {
        if (!p || isProxy(p))
            return true;
        return !p.isPlaying && (!p.trackTitle || p.trackTitle.length === 0);
    }

    function otherPlaying(self) {
        var l = root.list;
        for (var i = 0; i < l.length; i++)
            if (l[i] !== self && l[i].isPlaying)
                return true;
        return false;
    }

    readonly property var list: {
        var all = Mpris.players.values;
        var out = [];
        for (var i = 0; i < all.length; i++)
            if (all[i] && !isProxy(all[i]))
                out.push(all[i]);
        return out;
    }

    readonly property var pickable: {
        var l = root.list;
        var out = [];
        for (var i = 0; i < l.length; i++)
            if (!isIdle(l[i]))
                out.push(l[i]);
        return out;
    }

    property var manualActive: null
    property var preferred: null

    property bool ready: false
    Component.onCompleted: ready = true


    onListChanged: {
        if (manualActive && list.indexOf(manualActive) < 0)
            manualActive = null;
        if (preferred && list.indexOf(preferred) < 0)
            preferred = null;
    }


    readonly property var autoPick: {
        var l = root.list;
        if (l.length === 0)
            return null;
        if (preferred && l.indexOf(preferred) >= 0 && preferred.isPlaying)
            return preferred;
        for (var i = 0; i < l.length; i++)
            if (l[i].isPlaying && !isIdle(l[i]))
                return l[i];
        if (preferred && l.indexOf(preferred) >= 0 && !isIdle(preferred))
            return preferred;
        for (var j = 0; j < l.length; j++)
            if (!isIdle(l[j]) && l[j].trackTitle)
                return l[j];
        return l[0];
    }

    readonly property var active: (manualActive && list.indexOf(manualActive) >= 0 && !isIdle(manualActive)) ? manualActive : autoPick

    function select(p) {
        root.manualActive = (p && list.indexOf(p) >= 0) ? p : null;
    }

    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData
            readonly property bool real: modelData && !Players.isProxy(modelData)
            readonly property bool playing: real ? modelData.isPlaying : false

            onPlayingChanged: {
                if (!Players.ready)
                    return;
                if (playing) {
                    if (!Players.isIdle(modelData) && !Players.otherPlaying(modelData))
                        Players.preferred = modelData;
                }
            }


        }
    }

    readonly property bool has: active !== null
    readonly property bool playing: has && active.isPlaying

    readonly property string title: has ? (active.trackTitle || labelOf(active)) : ""
    readonly property string artist: has ? Theme.joinArtists(active.trackArtists, active.trackArtist) : ""
    readonly property string trackUrl: urlOf(active)
    readonly property string artUrl: artUrlFor(active)
    readonly property real lengthSec: mprisLengthFor(active)
    readonly property bool durationKnown: has && lengthSec > 0 && !live

    readonly property bool live: has && liveFor(active)
    readonly property string source: serviceOf(active)
    readonly property string serviceLabel: source.length > 0
        ? source.charAt(0).toUpperCase() + source.slice(1) : ""


    function keyFor(p) {
        return p ? ((p.dbusName || "") + "|" + (p.trackTitle || "") + "|" + artUrlFor(p)) : "";
    }
    readonly property string trackKey: has ? keyFor(active) : ""


    function urlOf(p) {
        return (p && p.metadata) ? (p.metadata["xesam:url"] || "") : "";
    }

    function finiteSeconds(v) {
        var n = Number(v);
        return isNaN(n) || !isFinite(n) ? 0 : n;
    }

    function mprisLengthFor(p) {
        if (!p)
            return 0;
        var len = finiteSeconds(p.length);
        if (!(len > 0) || len > 86400 || p.lengthSupported === false)
            return 0;
        return len;
    }


    function liveFor(p) {
        return p !== null && finiteSeconds(p.length) > 86400;
    }

    function serviceOf(p) {
        if (!p)
            return "";
        var site = siteName(urlOf(p));
        if (site.length === 0)
            site = siteFromTitle(p.trackTitle ? p.trackTitle : "");
        if (site.length > 0)
            return site;
        var n = p.identity ? p.identity : (p.desktopEntry ? p.desktopEntry : "");
        return n.toLowerCase();
    }

    function labelOf(p) {
        var s = serviceOf(p);
        if (s.length > 0)
            return s.charAt(0).toUpperCase() + s.slice(1);
        return p && p.identity ? p.identity : "";
    }

    function nowPlayingFor(p) {
        return p && p.trackTitle ? p.trackTitle : "";
    }


    function appIconFor(p) {
        if (!p)
            return "";
        var id = (p.desktopEntry && p.desktopEntry.length > 0) ? p.desktopEntry : (p.identity || "");
        if (id.length === 0)
            return "";
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === id.toLowerCase() && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
        return Quickshell.iconPath(id.toLowerCase(), "application-x-executable");
    }

    function artUrlFor(p) {
        return p && p.trackArtUrl ? p.trackArtUrl : "";
    }

    function siteName(url) {
        var m = url.match(/^https?:\/\/(?:www\.)?([^\/]+)/);
        if (!m)
            return "";
        var host = m[1].toLowerCase();
        if (host === "youtu.be")
            return "youtube";
        var parts = host.split(".");
        return parts.length >= 2 ? parts[parts.length - 2] : parts[0];
    }


    function siteFromTitle(t) {
        var m = t.match(/[|\-–—]\s*([A-Za-z][A-Za-z0-9]+)\s*$/);
        if (!m)
            return "";
        var s = m[1].toLowerCase();
        var known = { youtube: 1, spotify: 1, twitch: 1, soundcloud: 1, bandcamp: 1 };
        return known[s] ? s : "";
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
