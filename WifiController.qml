pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Networking
import "lib/network.js" as Network

Item {
    id: root
    visible: false
    property bool active: false
    signal connected()

    readonly property var devices: Networking.devices.values
    readonly property var wifiDev: devices.find(d => d && d.type === DeviceType.Wifi) || null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var nets: wifiDev ? wifiDev.networks.values : []
    readonly property var netsSorted: nets.slice().sort((a, b) => b.signalStrength - a.signalStrength)
    readonly property var activeNet: nets.find(n => n.connected) || null
    readonly property string statusText: !wifiOn ? "Off" : (activeNet ? activeNet.name : "Not connected")
    property var securityMap: Object.create(null)
    // SSID -> profile UUID. Ambiguous duplicate SSIDs are omitted from profile actions.
    property var knownProfiles: Object.create(null)
    readonly property bool connecting: connProc.running
    property bool connectFailed: false
    property bool scanning: false
    property string pendingPw: ""
    property string revealedSsid: ""
    property string revealedPw: ""
    property bool revealResolved: false
    property int revealRevision: 0
    property var profileQueue: []
    property var profileSnapshot: Object.create(null)
    property bool refreshPending: false

    function isSecured(ssid) {
        var security = securityMap[ssid];
        // Missing scan data must not be treated as proof of an open network.
        return security === undefined || (security !== "" && security !== "--");
    }

    function refresh() {
        if (!secProc.running) secProc.running = true;
        if (profProc.running || profileProc.running || profileQueue.length) {
            refreshPending = true;
            return;
        }
        profProc.running = true;
    }

    function nextProfile() {
        if (profileQueue.length) {
            profileProc.profileId = profileQueue.shift();
            profileProc.command = ["env", "LC_ALL=C", "nmcli", "-t", "-e", "yes", "-g", "802-11-wireless.ssid", "connection", "show", "uuid", profileProc.profileId];
            profileProc.running = true;
        } else {
            knownProfiles = profileSnapshot;
            if (refreshPending) { refreshPending = false; Qt.callLater(refresh); }
        }
    }

    function toggleWifi() { Networking.wifiEnabled = !wifiOn; }
    function connectKnown(net) { if (net) net.connect(); }
    function disconnectNetwork(net) { if (net) net.disconnect(); }

    function forgetNetwork(ssid) {
        var id = knownProfiles[ssid];
        if (forgetProc.running || !Network.uuid(id)) return;
        hidePassword();
        forgetProc.command = ["nmcli", "connection", "delete", "uuid", id];
        forgetProc.running = true;
    }

    function hidePassword() {
        revealRevision++;
        revealedSsid = "";
        revealedPw = "";
        revealResolved = false;
        revealProc.result = "";
        if (revealProc.running) revealProc.running = false;
    }

    function revealPassword(ssid) {
        if (revealedSsid === ssid) { hidePassword(); return; }
        // Allow a stopped process to exit before another request uses its collector.
        if (revealProc.running) { hidePassword(); return; }
        hidePassword();
        var id = knownProfiles[ssid];
        if (!Network.uuid(id)) return;
        revealedSsid = ssid;
        revealProc.revision = revealRevision;
        revealProc.command = ["nmcli", "-s", "-e", "no", "-g", "802-11-wireless-security.psk", "connection", "show", "uuid", id];
        revealProc.running = true;
    }

    function connectWithPassword(ssid, pw) {
        if (connecting) return;
        if (!Network.lineInput(ssid) || !Network.lineInput(pw)) {
            connectFailed = true;
            return;
        }
        connectFailed = false;
        pendingPw = pw;
        connProc.command = ["nmcli", "--wait", "30", "--ask", "dev", "wifi", "connect", ssid];
        connProc.running = true;
    }

    function startScan() {
        if (!wifiOn || rescanProc.running) return;
        scanning = true;
        rescanProc.running = true;
        scanTimer.restart();
    }
    function stopScan() { scanning = false; scanTimer.stop(); }

    onActiveChanged: {
        if (active) refresh();
        else { stopScan(); hidePassword(); pendingPw = ""; connectFailed = false; }
    }
    onWifiOnChanged: if (!wifiOn) { stopScan(); hidePassword(); }
    onNetsChanged: if (active) secRefresh.restart()

    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.active && root.wifiOn
        when: root.wifiDev !== null
    }
    Timer { id: scanTimer; interval: 10000; onTriggered: root.stopScan() }
    Timer { id: secRefresh; interval: 1200; onTriggered: root.refresh() }
    Process { id: rescanProc; command: ["nmcli", "dev", "wifi", "rescan"] }

    Process {
        id: secProc
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-e", "yes", "-f", "SSID,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector { id: securityOutput }
        onExited: (code) => {
            if (code !== 0) return;
            var map = Object.create(null);
            securityOutput.text.split("\n").forEach(function(line) {
                var fields = Network.fields(line);
                if (fields && fields.length === 2 && fields[0]) map[fields[0]] = fields[1];
            });
            root.securityMap = map;
        }
    }
    Process {
        id: profProc
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "UUID,TYPE", "connection", "show"]
        stdout: StdioCollector { id: profilesOutput }
        onExited: (code) => {
            if (code !== 0) { root.refreshPending = false; return; }
            root.profileQueue = profilesOutput.text.split("\n").map(Network.fields)
                .filter(p => p && p[1] === "802-11-wireless" && Network.uuid(p[0])).map(p => p[0]);
            root.profileSnapshot = Object.create(null);
            root.nextProfile();
        }
    }
    Process {
        id: profileProc
        property string profileId: ""
        stdout: StdioCollector { id: profileOutput }
        onExited: (code) => {
            var fields = Network.fields(profileOutput.text.replace(/\n$/, ""));
            if (code === 0 && fields && fields.length === 1 && Network.lineInput(fields[0])) {
                var ssid = fields[0];
                root.profileSnapshot[ssid] = root.profileSnapshot[ssid] === undefined ? profileId : "";
            }
            root.nextProfile();
        }
    }
    Process {
        id: connProc
        stdinEnabled: true
        // Discard nmcli prompts so passwords can never reach shell logs.
        stdout: SplitParser {}
        stderr: SplitParser {}
        onStarted: { write(root.pendingPw + "\n"); stdinEnabled = false; root.pendingPw = ""; }
        onExited: (code) => {
            stdinEnabled = true;
            root.pendingPw = "";
            root.connectFailed = root.active && code !== 0;
            if (code === 0) { root.connected(); root.refresh(); }
        }
    }
    Process {
        id: forgetProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refresh()
    }
    Process {
        id: revealProc
        property int revision: -1
        property string result: ""
        stdout: SplitParser {
            onRead: (data) => {
                if (revealProc.revision === root.revealRevision && root.active)
                    revealProc.result = data;
            }
        }
        stderr: SplitParser {}
        onExited: (code) => {
            if (revision === root.revealRevision && root.active) {
                root.revealedPw = code === 0 ? result : "";
                root.revealResolved = true;
            }
            result = "";
        }
    }
}
