pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth

Item {
    id: root
    property bool active: false
    visible: false
    onActiveChanged: if (!active) stopScan()
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []
    property var scanAdapter: null
    onAdapterChanged: { stopScan(); pairingDevice = null; failedAddress = ""; }

    readonly property var devicesSorted: devices.slice().sort(function(a, b) {
        function rank(d) {
            if (!d) return 3;
            if (d.connected) return 0;
            if (d.paired) return 1;
            return (d.name && d.name.length) ? 2 : 3;
        }
        var r = rank(a) - rank(b);
        if (r !== 0) return r;
        return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
    })
    readonly property bool discovering: scanAdapter ? scanAdapter.discovering : false

    property var pairingDevice: null
    property string failedAddress: ""

    function pairDevice(device) {
        if (!device || device.paired || pairingDevice) return;
        failedAddress = "";
        pairingDevice = device;
        device.pair();
    }

    function finishPairing() {
        var device = pairingDevice;
        if (!device || device.pairing) return;
        pairingDevice = null;
        if (device.paired) {
            device.trusted = true;
            if (!device.connected) device.connect();
        } else failedAddress = device.address;
    }

    Connections {
        target: root.pairingDevice
        function onPairedChanged() { root.finishPairing(); }
        function onPairingChanged() { Qt.callLater(root.finishPairing); }
    }

    function startScan() {
        if (!adapter || adapter.enabled !== true)
            return;

        stopScan();
        scanAdapter = adapter;
        scanAdapter.discovering = true;
        scanTimer.restart();
    }

    function stopScan() {
        scanTimer.stop();
        if (scanAdapter) scanAdapter.discovering = false;
        scanAdapter = null;
    }

    Component.onDestruction: {
        stopScan();
        if (pairingDevice && pairingDevice.pairing) pairingDevice.cancelPair();
    }

    Connections {
        target: root.adapter
        function onEnabledChanged() { if (!root.adapter.enabled) root.stopScan(); }
    }

    function toggleAdapter() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    Timer {
        id: scanTimer
        interval: 25000
        repeat: false
        onTriggered: root.stopScan()
    }

}
