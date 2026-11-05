pragma Singleton
import Quickshell
import Quickshell.Networking

Singleton {
    readonly property var devices: Networking.devices.values
    readonly property var ethernet: devices.find(d => d.type === DeviceType.Wired && d.connected) || null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var networks: wifi ? wifi.networks.values : []
    readonly property var activeNetwork: networks.find(n => n.connected) || null
    readonly property string wifiStatus: !wifiEnabled ? "Off"
        : activeNetwork ? activeNetwork.name : "Not connected"
    function toggleWifi() { Networking.wifiEnabled = !wifiEnabled; }
}
