pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "lib/network.js" as Network

Item {
    id: root
    property bool active: false
    visible: false
    onActiveChanged: if (!active) stopScan()
    readonly property var adapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var adapterDevices: (adapter && adapter.devices) ? adapter.devices.values : []
    readonly property var globalDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    property var scanDevices: []
    readonly property var devices: {
        var out = [];
        var seen = Object.create(null);
        for (var i = 0; i < adapterDevices.length; i++)
            addDevice(out, seen, adapterDevices[i]);
        for (var j = 0; j < globalDevices.length; j++)
            addDevice(out, seen, globalDevices[j]);
        for (var k = 0; k < scanDevices.length; k++)
            addDevice(out, seen, scanDevices[k]);
        return out;
    }


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
    readonly property bool discovering: scanProc.running

    property string pairingAddress: ""
    property string failedAddress: ""


    function addressOf(d) {
        return (d && d.address) ? String(d.address) : "";
    }

    function addDevice(out, seen, d) {
        if (!d)
            return;
        var addr = addressOf(d);
        var key = addr.length ? addr : String((d.deviceName || d.name || "") + "|" + out.length);
        if (seen[key])
            return;
        seen[key] = true;
        out.push(d);
    }

    function stripAnsi(text) {
        return String(text).replace(/\u001b\[[0-9;]*m/g, "").trim();
    }

    function rememberScannedDevice(addr, name) {
        if (!Network.mac(addr))
            return;

        var arr = scanDevices.slice();
        var cleanName = (name && name.length) ? name : "";
        if (cleanName.toUpperCase() === addr || cleanName.toUpperCase() === addr.replace(/:/g, "-"))
            cleanName = "";
        var label = cleanName.length ? cleanName : addr;
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].address === addr) {
                if (cleanName.length && arr[i].name !== cleanName)
                    arr[i] = { address: addr, name: cleanName, deviceName: label, connected: false, paired: false, scanned: true };
                scanDevices = arr;
                return;
            }
        }
        arr.push({ address: addr, name: cleanName, deviceName: label, connected: false, paired: false, scanned: true });
        scanDevices = arr;
    }

    function ingestScanLine(line) {
        var clean = stripAnsi(line);
        var m = clean.match(/\[NEW\] Device ([0-9A-Fa-f:]{17})(?: (.*))?$/);
        if (m) {
            rememberScannedDevice(m[1].toUpperCase(), (m[2] || "").trim());
            return;
        }

        m = clean.match(/\[CHG\] Device ([0-9A-Fa-f:]{17}) (Name|Alias): (.*)$/);
        if (m)
            rememberScannedDevice(m[1].toUpperCase(), (m[3] || "").trim());
    }

    function pairDevice(d) {
        if (!d || !Network.mac(d.address) || pairProc.running)
            return;
        pairingAddress = d.address;
        failedAddress = "";
        pairProc.command = ["sh", "-c",
            'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"',
            "sh", d.address];
        pairProc.running = true;
    }

    function startScan() {
        if (!adapter || adapter.enabled !== true)
            return;

        scanDevices = [];
        scanProc.command = ["bluetoothctl", "--timeout", "25", "scan", "on"];
        scanProc.running = true;
        scanTimer.restart();
    }

    function stopScan() {
        scanTimer.stop();
        if (scanProc.running)
            scanProc.running = false;
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

    Timer {
        id: failTimer
        interval: 4000
        repeat: false
        onTriggered: root.failedAddress = ""
    }

    Process {
        id: pairProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            var addr = root.pairingAddress;
            root.pairingAddress = "";
            if (exitCode !== 0) {
                root.failedAddress = addr;
                failTimer.restart();
            }
        }
    }

    Process {
        id: scanProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.ingestScanLine(data); }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.ingestScanLine(data); }
        }
        onExited: {
            scanTimer.stop();
        }
    }


    function connectDevice(d) {
        if (d && typeof d.connect === "function")
            d.connect();
    }

    function disconnectDevice(d) {
        if (d && typeof d.disconnect === "function")
            d.disconnect();
    }

    function forgetDevice(d) {
        if (d && typeof d.forget === "function")
            d.forget();
    }
}
