pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "Singletons"


Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    readonly property var devices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var nets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var netsSorted: nets.slice().sort(function(a, b) {
        return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
    })
    readonly property var activeNet: nets.find(function(n) { return n && n.connected }) || null
    readonly property string statusText: !wifiOn ? "Off"
        : (activeNet ? (activeNet.name || "Connected") : "Not connected")

    property var securityMap: ({})
    property var knownProfiles: ({})
    property string expandedSsid: ""
    property bool connecting: false
    property bool connectFailed: false
    property bool scanning: false
    property int navIndex: 0
    property string actionFocus: "row"
    property string focusTarget: "list"


    property string revealedSsid: ""
    property string revealedPw: ""
    property bool revealResolved: false

    readonly property string hsCon: "RicelinHotspot"
    readonly property string hsIface: wifiDev ? (wifiDev.name || "wlan0") : "wlan0"
    property string computerName: ""
    property bool hsNameFromProfile: false
    property string hsName: "Ricelin"
    property string hsPw: ""
    property bool hsActive: false
    property bool hsBusy: false
    property string hsEdit: ""
    property string hsDraft: ""


    property string pwDraft: ""
    property string pendingPw: ""
    property string attemptSsid: ""
    property bool attemptWasKnown: false

    readonly property int netCount: netsSorted.length
    readonly property int rowCount: netCount + (wifiOn ? 1 : 0)
    readonly property bool listFocused: focusTarget === "list"
    readonly property bool hotspotFocused: wifiOn && listFocused && navIndex === netCount
    readonly property var focusTargets: {
        var targets = ["back"];
        if (wifiOn)
            targets.push("scan");
        targets.push("toggle");
        if (rowCount > 0)
            targets.push("list");
        return targets;
    }

    implicitHeight: hsBlock.y + hsBlock.height

    function isSecured(ssid) {
        var sec = securityMap[ssid];
        return sec !== undefined && sec !== "" && sec !== "--";
    }

    function refresh() {
        secProc.running = true;
        profProc.running = true;
    }


    function splitTerse(line) {
        for (var k = line.length - 1; k >= 0; k--) {
            if (line[k] === ":" && (k === 0 || line[k - 1] !== "\\"))
                return { head: line.slice(0, k).replace(/\\:/g, ":"), tail: line.slice(k + 1) };
        }
        return null;
    }


    function activateNetwork(net) {
        if (!net)
            return;
        var ssid = net.name || "";
        if (expandedSsid === ssid && ssid.length) {
            expandedSsid = "";
            return;
        }
        if (net.connected || knownProfiles[ssid] === true) {
            connectFailed = false;
            pwDraft = "";
            expandedSsid = ssid;
            return;
        }
        if (!isSecured(ssid)) {
            expandedSsid = "";
            if (typeof net.connect === "function")
                net.connect();
            refresh();
            return;
        }
        connectFailed = false;
        pwDraft = "";
        expandedSsid = ssid;
    }


    function connectKnown(net) {
        if (!net)
            return;
        expandedSsid = "";
        if (typeof net.connect === "function")
            net.connect();
        refresh();
    }

    function disconnectNetwork(net) {
        if (!net)
            return;
        expandedSsid = "";
        if (typeof net.disconnect === "function")
            net.disconnect();
        refresh();
    }


    function forgetNetwork(ssid) {
        if (forgetProc.running || !ssid.length)
            return;
        expandedSsid = "";
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
    }


    function revealPassword(ssid) {
        if (!ssid.length)
            return;
        if (revealedSsid === ssid) {
            hidePassword();
            return;
        }
        revealedSsid = ssid;
        revealedPw = "";
        revealResolved = false;
        revealProc.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "id", ssid];
        revealProc.running = true;
    }

    function hidePassword() {
        revealedSsid = "";
        revealedPw = "";
        revealResolved = false;
    }

    function currentNet() {
        return navIndex >= 0 && navIndex < netCount ? netsSorted[navIndex] : null;
    }

    function currentActionNames() {
        if (hotspotFocused)
            return ["row"];

        var net = currentNet();
        if (!net)
            return [];

        var names = ["row"];
        var ssid = net.name || "";
        if (expandedSsid === ssid && (net.connected || knownProfiles[ssid] === true)) {
            names.push("primary");
            if (knownProfiles[ssid] === true)
                names.push("reveal");
            names.push("forget");
        }
        return names;
    }

    function normalizeNav() {
        if (rowCount === 0) {
            navIndex = -1;
            actionFocus = "row";
            return;
        }
        if (navIndex < 0)
            navIndex = 0;
        else if (navIndex >= rowCount)
            navIndex = rowCount - 1;

        var names = currentActionNames();
        if (names.indexOf(actionFocus) < 0)
            actionFocus = "row";
    }

    function normalizeFocusTarget() {
        if (focusTargets.length === 0) {
            focusTarget = "";
            return;
        }
        if (focusTargets.indexOf(focusTarget) >= 0)
            return;
        var listIdx = focusTargets.indexOf("list");
        var scanIdx = focusTargets.indexOf("scan");
        focusTarget = listIdx >= 0 ? "list"
            : scanIdx >= 0 ? "scan"
            : focusTargets[focusTargets.length - 1];
    }

    function headerFocused(name) {
        return active && focusTarget === name;
    }

    function scrollToNav() {
        if (!wifiOn || navIndex < 0)
            return;
        var maxY = Math.max(0, netFlick.contentHeight - netFlick.height);
        if (maxY <= 0) {
            netFlick.contentY = 0;
            return;
        }
        if (navIndex < netCount)
            netFlick.contentY = Math.max(0, Math.min(maxY, navIndex * 34 * s - netFlick.height / 2 + 17 * s));
    }

    function moveNav(dir) {
        if (rowCount === 0)
            return false;
        if (focusTarget !== "list") {
            focusTarget = "list";
            normalizeNav();
            scrollToNav();
            return true;
        }
        normalizeNav();
        navIndex = (navIndex + dir + rowCount) % rowCount;
        actionFocus = "row";
        scrollToNav();
        return true;
    }

    function moveAction(dir) {
        if (focusTarget !== "list")
            return moveTab(dir);
        normalizeNav();
        var names = currentActionNames();
        if (names.length <= 1)
            return false;
        var idx = names.indexOf(actionFocus);
        if (idx < 0)
            idx = 0;
        actionFocus = names[(idx + dir + names.length) % names.length];
        return true;
    }

    function moveTab(dir) {
        if (focusTargets.length === 0)
            return false;
        normalizeFocusTarget();
        var idx = focusTargets.indexOf(focusTarget);
        if (idx < 0)
            idx = 0;
        focusTarget = focusTargets[(idx + dir + focusTargets.length) % focusTargets.length];
        if (focusTarget === "list") {
            normalizeNav();
            scrollToNav();
        }
        return true;
    }

    function toggleWifi() {
        if (typeof Networking !== "undefined" && Networking)
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleHotspot() {
        if (hsActive) {
            stopHotspot();
        } else {
            if (hsPw.length < 8)
                hsPw = generatePw();
            applyHotspot();
        }
    }

    function activateFocused() {
        if (focusTarget === "back") {
            back();
            return true;
        }
        if (focusTarget === "scan") {
            if (scanning)
                stopScan();
            else
                startScan();
            return true;
        }
        if (focusTarget === "toggle") {
            toggleWifi();
            return true;
        }

        normalizeNav();
        if (hotspotFocused) {
            toggleHotspot();
            return true;
        }

        var net = currentNet();
        if (!net)
            return false;

        if (actionFocus === "primary") {
            if (net.connected)
                disconnectNetwork(net);
            else
                connectKnown(net);
            return true;
        }
        if (actionFocus === "reveal") {
            revealPassword(net.name || "");
            return true;
        }
        if (actionFocus === "forget") {
            forgetNetwork(net.name || "");
            return true;
        }
        activateNetwork(net);
        return true;
    }

    function keyPress(key, isAutoRepeat) {
        if (key === Qt.Key_Tab)
            return moveTab(1);
        if (key === Qt.Key_Backtab)
            return moveTab(-1);
        if (key === Qt.Key_K || key === Qt.Key_Up)
            return moveNav(-1);
        if (key === Qt.Key_J || key === Qt.Key_Down)
            return moveNav(1);
        if (key === Qt.Key_H || key === Qt.Key_Left)
            return moveAction(-1);
        if (key === Qt.Key_L || key === Qt.Key_Right)
            return moveAction(1);
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
            return activateFocused();
        return false;
    }


    function connectWithPassword(ssid, pw) {
        if (connProc.running || !pw.length)
            return;
        connecting = true;
        connectFailed = false;
        attemptSsid = ssid;
        attemptWasKnown = knownProfiles[ssid] === true;
        pendingPw = pw;
        connProc.command = ["nmcli", "--ask", "dev", "wifi", "connect", ssid];
        connProc.running = true;
    }


    function startScan() {
        if (!wifiOn)
            return;
        scanning = true;
        rescanProc.running = true;
        scanTimer.restart();
    }

    function stopScan() {
        scanning = false;
        scanTimer.stop();
    }

    onActiveChanged: {
        if (active) {
            refresh();
            refreshHotspot();
            normalizeFocusTarget();
            normalizeNav();
            scrollToNav();
        } else {
            stopScan();
            focusTarget = "list";
            expandedSsid = "";
            connectFailed = false;
            hsEdit = "";
            hidePassword();
        }
    }

    onWifiOnChanged: {
        if (!wifiOn)
            stopScan();
        normalizeFocusTarget();
        normalizeNav();
    }

    onExpandedSsidChanged: {
        if (revealedSsid !== expandedSsid)
            hidePassword();
        normalizeNav();
    }
    onRowCountChanged: {
        normalizeFocusTarget();
        normalizeNav();
    }
    onKnownProfilesChanged: normalizeNav()

    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.active && root.wifiOn
        when: root.wifiDev !== null
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: root.stopScan()
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
    }


    function applyHotspot() {
        if (hsBusy || hsPw.length < 8)
            return;
        hsBusy = true;
        hsApplyProc.command = ["sh", "-c",
            'c="' + hsCon + '"; '
            + 'if nmcli -t connection show "$c" >/dev/null 2>&1; then '
            +   'nmcli connection modify "$c" 802-11-wireless.ssid "$1" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2"; '
            + 'else '
            +   'nmcli connection add type wifi ifname "$3" con-name "$c" autoconnect no 802-11-wireless.ssid "$1" 802-11-wireless.mode ap 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2" ipv4.method shared; '
            + 'fi; '
            + 'nmcli connection up "$c"',
            "sh", hsName, hsPw, hsIface];
        hsApplyProc.running = true;
    }

    function stopHotspot() {
        if (hsBusy)
            return;
        hsBusy = true;
        hsDownProc.running = true;
    }

    function refreshHotspot() {
        hsStateProc.running = true;
        hsReadProc.running = true;
    }


    function commitHotspotEdit() {
        if (hsEdit === "name") {
            if (hsDraft.length)
                hsName = hsDraft;
        } else if (hsEdit === "pw") {
            if (hsDraft.length >= 8)
                hsPw = hsDraft;
        }
        hsEdit = "";
        if (hsActive)
            applyHotspot();
    }


    function generatePw() {
        var cs = "abcdefghijkmnpqrstuvwxyz23456789";
        var s = "";
        for (var i = 0; i < 8; i++)
            s += cs.charAt(Math.floor(Math.random() * cs.length));
        return s;
    }

    Process {
        id: hsApplyProc
        onExited: {
            root.hsBusy = false;
            root.refreshHotspot();
        }
    }

    Process {
        id: hsDownProc
        command: ["nmcli", "connection", "down", root.hsCon]
        onExited: {
            root.hsBusy = false;
            root.refreshHotspot();
        }
    }

    Process {
        id: hsStateProc
        command: ["sh", "-c", "nmcli -t -f NAME connection show --active | grep -qx \"$1\" && echo on || echo off", "sh", root.hsCon]
        stdout: StdioCollector {
            onStreamFinished: root.hsActive = this.text.trim() === "on"
        }
    }


    Process {
        id: hostNameProc
        command: ["hostname", "-s"]
        Component.onCompleted: running = true
        stdout: StdioCollector {
            onStreamFinished: {
                var name = this.text.trim();
                if (!name.length)
                    return;
                root.computerName = name;
                if (!root.hsNameFromProfile)
                    root.hsName = name;
            }
        }
    }

    Process {
        id: hsReadProc
        command: ["nmcli", "-t", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.psk", "connection", "show", root.hsCon]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                root.hsNameFromProfile = lines.length >= 1 && lines[0].length > 0;
                if (root.hsNameFromProfile)
                    root.hsName = lines[0];
                else
                    root.hsName = root.computerName.length ? root.computerName : "Ricelin";
                if (lines.length >= 2 && lines[1].length)
                    root.hsPw = lines[1];
            }
        }
    }

    Process {
        id: secProc
        command: ["nmcli", "-t", "-f", "SSID,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].length)
                        continue;
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length)
                        map[parts.head] = parts.tail;
                }
                root.securityMap = map;
            }
        }
    }

    Process {
        id: profProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length && parts.tail === "802-11-wireless")
                        set[parts.head] = true;
                }
                root.knownProfiles = set;
            }
        }
    }

    Process {
        id: connProc
        stdinEnabled: true
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onStarted: {
            write(root.pendingPw + "\n");
            root.pendingPw = "";
        }
        onExited: function(exitCode) {
            root.connecting = false;
            if (exitCode === 0) {
                root.expandedSsid = "";
                root.pwDraft = "";
                root.connectFailed = false;
                root.refresh();
            } else {
                root.connectFailed = true;
                if (!root.attemptWasKnown && root.attemptSsid.length) {
                    cleanupProc.command = ["nmcli", "connection", "delete", "id", root.attemptSsid];
                    cleanupProc.running = true;
                }
            }
        }
    }


    Process {
        id: cleanupProc
        onExited: root.refresh()
    }


    Process {
        id: forgetProc
        onExited: root.refresh()
    }


    Process {
        id: revealProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.revealedPw = this.text.replace(/\n+$/, "");
                root.revealResolved = true;
            }
        }
    }

    onNetsChanged: if (active) secRefresh.restart()

    Timer {
        id: secRefresh
        interval: 1200
        onTriggered: if (root.active) secProc.running = true
    }


    ScriptModel {
        id: netModel
        objectProp: "name"
        values: root.netsSorted
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 17 * root.s
                height: 17 * root.s

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    radius: 6 * root.s
                    color: backArea.containsMouse || root.headerFocused("back") ? Theme.frameBg : "transparent"
                    border.width: root.headerFocused("back") ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.85)
                }

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    color: backArea.containsMouse || root.headerFocused("back") ? Theme.cream : Theme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "WIFI"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "· " + root.statusText
                color: root.activeNet ? Theme.vermLit : Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.wifiOn
                width: 16 * root.s
                height: 16 * root.s

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    radius: 6 * root.s
                    color: reloadArea.containsMouse || root.headerFocused("scan") ? Theme.frameBg : "transparent"
                    border.width: root.headerFocused("scan") ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.85)
                }

                GlyphIcon {
                    id: reloadGlyph
                    anchors.fill: parent
                    name: "reboot"
                    color: root.scanning ? Theme.flameGlow : (reloadArea.containsMouse || root.headerFocused("scan") ? Theme.cream : Theme.iconDim)
                    stroke: 1.8

                    RotationAnimator {
                        target: reloadGlyph
                        running: root.scanning
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) reloadGlyph.rotation = 0
                    }
                }

                MouseArea {
                    id: reloadArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.scanning ? root.stopScan() : root.startScan()
                }
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.wifiOn
                focused: root.headerFocused("toggle")
                onToggled: root.toggleWifi()
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.wifiOn ? Math.min(Math.max(netCol.implicitHeight, 26 * root.s), 280 * root.s) : 0
        readonly property bool scrollable: root.wifiOn && netCol.implicitHeight > height + 1

        Text {
            anchors.centerIn: parent
            visible: root.wifiOn && root.nets.length === 0
            text: "Searching networks…"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
        }

        Flickable {
            id: netFlick
            anchors.fill: parent
            contentHeight: netCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: netCol
                width: netFlick.width - (listFrame.scrollable ? 8 * root.s : 0)
                spacing: 2 * root.s

                Repeater {
                    model: netModel

                    Column {
                        id: netItem
                        required property int index
                        required property var modelData
                        readonly property string ssid: (modelData && modelData.name) ? modelData.name : ""
                        readonly property bool isActive: modelData ? modelData.connected === true : false
                        readonly property bool secured: root.isSecured(ssid)
                        readonly property bool known: root.knownProfiles[ssid] === true
                        readonly property bool expanded: ssid.length > 0 && root.expandedSsid === ssid
                        readonly property bool confirming: expanded && (isActive || known)
                        readonly property bool asking: expanded && !confirming
                        readonly property bool rowKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "row"
                        readonly property bool primaryKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "primary"
                        readonly property bool revealKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "reveal"
                        readonly property bool forgetKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "forget"
                        width: netCol.width
                        spacing: 2 * root.s

                        function syncPwField() {
                            pwField.text = root.pwDraft;
                            pwField.cursorPosition = pwField.text.length;
                            pwField.forceActiveFocus();
                        }

                        onExpandedChanged: if (asking) Qt.callLater(syncPwField)
                        Component.onCompleted: if (asking) Qt.callLater(syncPwField)

                        Rectangle {
                            width: parent.width
                            height: 30 * root.s
                            radius: 9 * root.s
                            color: netItem.isActive ? Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.14)
                                : (rowHover.hovered || netItem.rowKeyFocus ? Theme.frameBg : "transparent")
                            border.width: netItem.rowKeyFocus ? 1 : 0
                            border.color: Qt.alpha(Theme.vermLit, 0.78)

                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateNetwork(netItem.modelData)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: rowRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.ssid.length ? netItem.ssid : "Hidden"
                                color: netItem.isActive ? Theme.vermLit : Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 11.5 * root.s
                                font.weight: netItem.isActive ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: rowRight
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * root.s

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -1.4 * root.s
                                    visible: netItem.secured
                                    width: 14 * root.s
                                    height: 14 * root.s

                                    GlyphIcon {
                                        anchors.fill: parent
                                        name: "lock-outline"
                                        color: netItem.isActive ? Theme.vermLit : Theme.iconDim
                                        stroke: 1.9
                                    }
                                }

                                WifiGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    s: root.s
                                    on: true
                                    level: (netItem.modelData && netItem.modelData.signalStrength) || 0
                                }
                            }
                        }

                        Item {
                            visible: netItem.confirming
                            width: parent.width
                            height: 30 * root.s

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: confirmBtns.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.isActive ? "Connected" : "Saved network"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 9.5 * root.s
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: confirmBtns
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6 * root.s

                                Rectangle {
                                    id: primaryBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: primaryLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: primaryArea.containsMouse || netItem.primaryKeyFocus ? Theme.tileBg : "transparent"
                                    border.width: 1
                                    border.color: netItem.primaryKeyFocus ? Qt.alpha(Theme.vermLit, 0.85)
                                        : (primaryArea.containsMouse ? Theme.vermDim : Theme.border)

                                    Text {
                                        id: primaryLabel
                                        anchors.centerIn: parent
                                        text: netItem.isActive ? "Disconnect" : "Connect"
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: primaryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: netItem.isActive
                                            ? root.disconnectNetwork(netItem.modelData)
                                            : root.connectKnown(netItem.modelData)
                                    }
                                }

                                Rectangle {
                                    id: revealBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: netItem.known
                                    readonly property bool shown: root.revealedSsid === netItem.ssid
                                    width: revealLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: revealArea.containsMouse || netItem.revealKeyFocus ? Theme.tileBg : "transparent"
                                    border.width: 1
                                    border.color: netItem.revealKeyFocus
                                        ? Qt.alpha(Theme.vermLit, 0.85)
                                        : revealBtn.shown
                                        ? Theme.vermDim
                                        : (revealArea.containsMouse ? Theme.vermDim : Theme.border)

                                    Text {
                                        id: revealLabel
                                        anchors.centerIn: parent
                                        text: revealBtn.shown ? "Hide" : "Show"
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: revealArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.revealPassword(netItem.ssid)
                                    }
                                }

                                Rectangle {
                                    id: forgetBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: forgetLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: forgetArea.containsMouse || netItem.forgetKeyFocus
                                        ? Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.2)
                                        : Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.12)
                                    border.width: 1
                                    border.color: netItem.forgetKeyFocus
                                        ? Qt.alpha(Theme.vermLit, 0.85)
                                        : Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.45)

                                    Text {
                                        id: forgetLabel
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        color: Theme.vermLit
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: forgetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.forgetNetwork(netItem.ssid)
                                    }
                                }
                            }
                        }

                        Item {
                            readonly property bool shown: netItem.confirming && root.revealedSsid === netItem.ssid
                            visible: shown
                            width: parent.width
                            height: shown ? 24 * root.s : 0

                            Text {
                                id: revealCaption
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PASSWORD"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 9 * root.s
                                font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1 * root.s
                            }

                            Text {
                                visible: root.revealResolved && root.revealedPw.length === 0
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: "no saved password"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10 * root.s
                                font.weight: Font.Medium
                            }

                            TextEdit {
                                visible: root.revealedPw.length > 0
                                anchors.left: revealCaption.right
                                anchors.leftMargin: 10 * root.s
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: TextEdit.AlignRight
                                readOnly: true
                                selectByMouse: true
                                selectionColor: Theme.verm
                                wrapMode: TextEdit.NoWrap
                                clip: true
                                text: root.revealedSsid === netItem.ssid ? root.revealedPw : ""
                                color: Theme.flameCore
                                font.family: Theme.font
                                font.pixelSize: 11.5 * root.s
                                font.weight: Font.Medium
                            }
                        }

                        Item {
                            visible: netItem.asking
                            width: parent.width
                            height: 30 * root.s

                            TextField {
                                id: pwField
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: pwRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                background: null
                                padding: 0
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 11.5 * root.s
                                echoMode: TextInput.Password
                                placeholderText: "Password"
                                placeholderTextColor: Theme.faint
                                selectByMouse: true
                                selectionColor: Theme.verm
                                onTextEdited: root.pwDraft = text
                                onAccepted: root.connectWithPassword(netItem.ssid, text)
                            }

                            Row {
                                id: pwRight
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.connecting && netItem.asking
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: Theme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: root.connecting && netItem.asking
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                    }
                                }

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14 * root.s
                                    height: 14 * root.s
                                    name: "return"
                                    color: enterArea.containsMouse ? Theme.cream : Theme.vermLit
                                    stroke: 1.8

                                    MouseArea {
                                        id: enterArea
                                        anchors.fill: parent
                                        anchors.margins: -6 * root.s
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connectWithPassword(netItem.ssid, pwField.text)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: netItem.asking && root.connectFailed
                            text: "Connection failed"
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 10 * root.s
                        }
                    }
                }
            }
        }

        Rectangle {
            id: netScrollTrack
            visible: listFrame.scrollable
            z: 10
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 3 * root.s
            anchors.bottomMargin: 3 * root.s
            width: Math.max(3, 4 * root.s)
            radius: width / 2
            color: Theme.frameBg
            opacity: root.scanning ? 1 : 0.82

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.max(18 * root.s, parent.height * Math.min(1, netFlick.height / Math.max(1, netFlick.contentHeight)))
                y: (parent.height - height) * (netFlick.contentY / Math.max(1, netFlick.contentHeight - netFlick.height))
                radius: width / 2
                color: root.scanning ? Theme.flameGlow : Theme.dim
                opacity: root.scanning ? 0.95 : 0.78
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: netFlick
        }
    }

    Item {
        id: hsBlock
        anchors.top: listFrame.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.wifiOn
        height: root.wifiOn ? hsCol.implicitHeight + 9 * root.s : 0
        clip: true

        Rectangle {
            id: hsDivider
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
        }

        Column {
            id: hsCol
            anchors.top: hsDivider.bottom
            anchors.topMargin: 9 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6 * root.s

            component CredRow: Item {
                id: cr
                property string field: ""
                property string label: ""
                property string value: ""
                property bool secret: false
                readonly property bool editing: root.hsEdit === cr.field
                width: parent ? parent.width : 0
                height: 22 * root.s

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: cr.label
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                }

                Text {
                    visible: !cr.editing
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: cr.value.length ? cr.value : "tap to set"
                    color: cr.value.length ? (cr.secret ? Theme.flameCore : Theme.cream) : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.hsDraft = cr.value;
                            root.hsEdit = cr.field;
                            Qt.callLater(crField.forceActiveFocus);
                        }
                    }
                }

                TextField {
                    id: crField
                    visible: cr.editing
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150 * root.s
                    horizontalAlignment: TextInput.AlignRight
                    background: null
                    padding: 0
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    placeholderText: cr.field === "pw" ? "8+ characters" : "Name"
                    placeholderTextColor: Theme.faint
                    selectByMouse: true
                    selectionColor: Theme.verm
                    text: cr.editing ? root.hsDraft : ""
                    onTextEdited: root.hsDraft = text
                    onAccepted: root.commitHotspotEdit()
                }
            }

            Rectangle {
                width: parent.width
                height: 34 * root.s
                radius: 10 * root.s
                color: root.hsActive || root.hotspotFocused ? Theme.frameBg : "transparent"
                border.width: root.hotspotFocused ? 1 : 0
                border.color: Qt.alpha(Theme.vermLit, 0.78)

                GlyphIcon {
                    id: hsGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: "hotspot"
                    color: root.hsActive ? Theme.flameGlow : Theme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: hsGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        text: "Hotspot"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.hsBusy ? "…" : (root.hsActive ? "Active" : "Off")
                        color: root.hsActive ? Theme.flameGlow : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                    }
                }

                LinkToggle {
                    s: root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.hsActive
                    onToggled: {
                        root.toggleHotspot();
                    }
                }
            }

            CredRow {
                field: "name"
                label: "Network"
                value: root.hsName
            }

            CredRow {
                field: "pw"
                label: "Password"
                value: root.hsPw
                secret: true
            }
        }
    }
}
