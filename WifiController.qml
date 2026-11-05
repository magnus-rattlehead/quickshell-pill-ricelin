pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking
import "Singletons"

Item {
    id: root
    visible: false
    property bool active: false
    signal connected()
    readonly property var wifiDev: NetworkState.wifi
    readonly property bool wifiOn: NetworkState.wifiEnabled
    readonly property var nets: NetworkState.networks
    readonly property var netsSorted: nets.slice().sort((a, b) => b.signalStrength - a.signalStrength)
    readonly property string statusText: NetworkState.wifiStatus
    // Only unambiguous profiles may be deleted individually.
    readonly property var knownProfiles: {
        var profiles = Object.create(null);
        for (var net of nets) {
            var saved = net.nmSettings || [];
            var profile = saved.length === 1 ? saved[0] : null;
            profiles[net.name] = profiles[net.name] === undefined ? profile : null;
        }
        return profiles;
    }
    property var pendingNetwork: null
    readonly property bool connecting: pendingNetwork !== null && pendingNetwork.stateChanging
    property bool connectFailed: false
    function isSecured(net) { return net.security !== WifiSecurityType.Open; }
    function connectNetwork(net, password) {
        if (!net || connecting) return;
        connectFailed = false;
        pendingNetwork = net;
        if (password === undefined) net.connect();
        else net.connectWithPsk(password);
    }
    function forgetNetwork(ssid) {
        var profile = knownProfiles[ssid];
        if (!profile) return;
        profile.forget();
    }
    onActiveChanged: if (!active) { pendingNetwork = null; connectFailed = false; }
    onWifiOnChanged: if (!wifiOn) pendingNetwork = null
    onNetsChanged: {
        if (pendingNetwork && nets.indexOf(pendingNetwork) < 0) pendingNetwork = null;
    }
    Connections {
        target: root.pendingNetwork
        function onConnectionFailed(reason) { root.connectFailed = root.active; }
        function onConnectedChanged() {
            if (root.pendingNetwork && root.pendingNetwork.connected) {
                root.connectFailed = false;
                root.connected();
                root.pendingNetwork = null;
            }
        }
    }
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.active && root.wifiOn
        when: root.wifiDev !== null
    }
}
