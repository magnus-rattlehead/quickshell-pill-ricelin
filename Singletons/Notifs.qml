pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var popup: null
    property bool popupExpanded: false
    readonly property int popupTimeout: !popup || popup.urgency === NotificationUrgency.Critical ? 0
        : popup.expireTimeout >= 0 ? popup.expireTimeout
        : popup.urgency === NotificationUrgency.Low ? 4000 : 6000
    readonly property var entries: server.trackedNotifications.values.slice().reverse()
    readonly property int count: entries.length
    onEntriesChanged: if (popup && !entries.includes(popup)) popup = null

    function clearAll() { entries.slice().forEach(n => n.dismiss()); }

    Timer {
        id: popupTimer
        interval: Math.max(1, root.popupTimeout)
        running: root.popup !== null && !root.popupExpanded && root.popupTimeout > 0
        onTriggered: root.popup = null
    }

    function iconFor(n) {
        if (n.image) return n.image;
        return Quickshell.iconPath(n.appIcon || n.desktopEntry || (n.appName || "").toLowerCase(), true);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: function(n) {
            n.tracked = true;
            if (!Flags.dnd || n.urgency === NotificationUrgency.Critical) {
                root.popupExpanded = false;
                root.popup = n;
                if (root.popupTimeout > 0) popupTimer.restart();
            }
        }
    }
}
