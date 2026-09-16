pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/safe.js" as Safe
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var seenIds: Object.create(null)
    property var arrivalMs: Object.create(null)
    property var popups: []
    property int tick: 0
    property var expandedApps: Object.create(null)
    property var history: []
    property var userDismissed: Object.create(null)
    property var expireAt: Object.create(null)
    property var hookedIds: Object.create(null)

    readonly property var tracked: server.trackedNotifications.values
    readonly property int count: tracked.length + history.length

    readonly property int unread: {
        var u = 0;
        for (var i = 0; i < tracked.length; i++)
            if (!seenIds[tracked[i].id]) u++;
        for (var j = 0; j < history.length; j++)
            if (!seenIds[history[j].id]) u++;
        return u;
    }

    readonly property var groups: {
        var map = Object.create(null);
        var order = [];
        for (var i = 0; i < tracked.length; i++) {
            var n = tracked[i];
            var app = (n.appName && n.appName.length) ? n.appName : "System";
            if (map[app] === undefined) { map[app] = []; order.push(app); }
            map[app].push({ live: true, n: n, t: arrivalMs[n.id] || 0 });
        }
        for (var j = 0; j < history.length; j++) {
            var h = history[j];
            if (map[h.app] === undefined) { map[h.app] = []; order.push(h.app); }
            map[h.app].push({ live: false, n: h, t: h.ts || 0 });
        }
        function coalesce(list, it) {
            var last = list.length > 0 ? list[list.length - 1] : null;
            if (last && last.n.summary === it.n.summary && last.n.body === it.n.body) {
                last.count++;
                last.items.push(it.n);
            } else {
                list.push({ live: it.live, n: it.n, count: 1, items: [it.n] });
            }
        }
        var gs = order.map(function(app) {
            var items = map[app];
            items.sort(function(a, b) { return b.t - a.t; });
            var criticals = [];
            var entries = [];
            for (var k = 0; k < items.length; k++)
                coalesce(items[k].n.urgency === NotificationUrgency.Critical ? criticals : entries, items[k]);
            var preview = items.find(function(it) { return it.n.urgency !== NotificationUrgency.Critical; });
            return {
                app: app,
                count: items.length,
                t: items[0].t,
                newest: items[0].n,
                preview: preview ? preview.n : items[0].n,
                criticals: criticals,
                entries: entries
            };
        });
        gs.sort(function(a, b) { return b.t - a.t; });
        return gs;
    }

    function iconFor(n) {
        if (!n) return "";
        var img = n.image || "";
        var names = [];
        if (img.indexOf("image://icon/") === 0) {
            names.push(img.substring(13));
        } else if (img.length && !/\.svg$/i.test(img)) {
            return img;
        }
        names.push(n.appIcon, n.desktopEntry, (n.appName || n.app || "").toLowerCase());
        for (var i = 0; i < names.length; i++) {
            var nm = names[i];
            if (!nm || !nm.length) continue;
            if (nm.indexOf("/") === 0 || nm.indexOf("file://") === 0) return nm;
            var p = Quickshell.iconPath(nm, true);
            if (p.length) return p;
        }
        return "";
    }

    function dismissEntry(e) {
        if (!e || !e.items) return;
        var d = Object.assign(Object.create(null), userDismissed);
        var gone = Object.create(null);
        var live = [];
        for (var i = 0; i < e.items.length; i++) {
            var n = e.items[i];
            if (typeof n.dismiss === "function") {
                d[n.id] = true;
                live.push(n);
            } else {
                gone[n.id] = true;
            }
        }
        root.userDismissed = d;
        for (var j = 0; j < live.length; j++) live[j].dismiss();
        root.history = root.history.filter(function(h) { return !gone[h.id]; });
    }


    function raiseWindow(n) {
        if (!n || focusProc.running) return;
        var token = String(n.desktopEntry || n.appName || "").toLowerCase();
        if (!token.length) return;
        focusProc.token = token;
        focusProc.running = true;
    }

    Process {
        id: focusProc
        property string token: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { id: clientsOutput }
        onExited: (code) => {
            if (code !== 0) return;
            try {
                var clients = JSON.parse(clientsOutput.text);
                if (!Array.isArray(clients)) return;
                var match = clients.find(c => c && [c.class, c.initialClass].some(
                    name => typeof name === "string" && name.toLowerCase().indexOf(token) !== -1));
                var address = match ? Safe.windowAddress(match.address) : "";
                if (address) Quickshell.execDetached(["hyprctl", "dispatch",
                    "hl.dsp.focus({ window = " + Safe.luaQuote("address:" + address) + " })"]);
            } catch (_) {}
        }
    }


    function activateNotif(n) {
        if (!n) return;
        var acts = n.actions || [];
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") {
                acts[i].invoke();
                break;
            }
        }
        raiseWindow(n);
    }


    function activateEntry(e) {
        if (!e || !e.n) return;
        activateNotif(e.n);
        dismissEntry(e);
    }

    function dismissApp(app) {
        var doomed = tracked.filter(function(n) {
            return ((n.appName && n.appName.length) ? n.appName : "System") === app;
        });
        var d = Object.assign(Object.create(null), userDismissed);
        for (var i = 0; i < doomed.length; i++) d[doomed[i].id] = true;
        root.userDismissed = d;
        for (var j = 0; j < doomed.length; j++) doomed[j].dismiss();
        root.history = root.history.filter(function(h) { return h.app !== app; });
    }

    function markAllSeen() {
        var m = Object.create(null);
        for (var i = 0; i < tracked.length; i++) m[tracked[i].id] = true;
        for (var j = 0; j < history.length; j++) m[history[j].id] = true;
        root.seenIds = m;
    }

    function clearAll() {
        var l = tracked.slice();
        var d = Object.assign(Object.create(null), userDismissed);
        for (var i = 0; i < l.length; i++) d[l[i].id] = true;
        root.userDismissed = d;
        for (var j = 0; j < l.length; j++) l[j].dismiss();
        root.history = [];
        root.popups = [];
    }

    function markEntrySeen(e) {
        if (!e || !e.items) return;
        var m = Object.assign(Object.create(null), seenIds);
        for (var i = 0; i < e.items.length; i++)
            m[e.items[i].id] = true;
        root.seenIds = m;
    }

    function markAppSeen(app) {
        var m = Object.assign(Object.create(null), seenIds);
        for (var i = 0; i < tracked.length; i++) {
            var n = tracked[i];
            if (((n.appName && n.appName.length) ? n.appName : "System") === app)
                m[n.id] = true;
        }
        for (var j = 0; j < history.length; j++)
            if (history[j].app === app)
                m[history[j].id] = true;
        root.seenIds = m;
    }

    function removePopup(n) {
        root.popups = root.popups.filter(function(p) { return p !== n; });
    }

    function toggleExpanded(app) {
        var e = Object.assign(Object.create(null), expandedApps);
        e[app] = e[app] !== true;
        root.expandedApps = e;
    }


    function hookClosed(n) {
        if (root.hookedIds[n.id])
            return;
        var hooked = Object.assign(Object.create(null), root.hookedIds);
        hooked[n.id] = true;
        root.hookedIds = hooked;
        n.closed.connect(function(reason) {
            if (!root.userDismissed[n.id]) {
                var hid = "h" + n.id + "-" + Date.now();
                if (root.seenIds[n.id]) {
                    var seen = Object.assign(Object.create(null), root.seenIds);
                    seen[hid] = true;
                    root.seenIds = seen;
                }
                root.history = [{
                    app: (n.appName && n.appName.length) ? n.appName : "System",
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    desktopEntry: n.desktopEntry,
                    image: n.image,
                    urgency: n.urgency,
                    ts: root.arrivalMs[n.id] || Date.now(),
                    id: hid
                }].concat(root.history).slice(0, 50);
            } else {
                var du = Object.assign(Object.create(null), root.userDismissed);
                delete du[n.id];
                root.userDismissed = du;
            }
            root.removePopup(n);
            var b = Object.assign(Object.create(null), root.arrivalMs);
            delete b[n.id];
            root.arrivalMs = b;
            var c = Object.assign(Object.create(null), root.expireAt);
            delete c[n.id];
            root.expireAt = c;
            var h = Object.assign(Object.create(null), root.hookedIds);
            delete h[n.id];
            root.hookedIds = h;
        });
    }

    function ageLabel(n) {
        void root.tick;
        var t = arrivalMs[n.id] || n.ts;
        if (!t) return "";
        var m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        return Math.floor(m / 60) + "h";
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.tick++
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        Component.onCompleted: {
            var l = trackedNotifications.values;
            var a = Object.assign(Object.create(null), root.arrivalMs);
            for (var i = 0; i < l.length; i++) {
                if (!a[l[i].id]) a[l[i].id] = Date.now();
                root.hookClosed(l[i]);
            }
            root.arrivalMs = a;
        }

        onNotification: function(n) {
            var a = Object.assign(Object.create(null), root.arrivalMs);
            a[n.id] = Date.now();
            root.arrivalMs = a;
            var e = Object.assign(Object.create(null), root.expireAt);
            e[n.id] = Date.now() + (n.urgency === NotificationUrgency.Low ? 4000 : 6000);
            root.expireAt = e;
            n.tracked = true;
            root.hookClosed(n);
            var critical = n.urgency === NotificationUrgency.Critical;
            if (!Flags.dnd || critical)
                root.popups = root.popups.concat([n]).slice(-3);
        }
    }
}
