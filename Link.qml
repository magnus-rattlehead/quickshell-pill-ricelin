pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth
import "Singletons"

PillSurface {
    id: root
    topPadding: 13 * s; leftPadding: 16 * s; rightPadding: 16 * s; bottomPadding: 13 * s
    property string subview: "main"
    implicitWidth: (subview === "wifi" ? 272 : subview === "bt" ? 286 : 330) * s
    contentItem.implicitHeight: subview === "wifi" ? wifiPage.implicitHeight
        : subview === "bt" ? btPage.implicitHeight : mainCol.implicitHeight

    readonly property var eth: NetworkState.ethernet
    readonly property bool wired: eth !== null

    readonly property real ethSpeed: (eth && eth.linkSpeed) ? eth.linkSpeed : 0
    readonly property string ethSpeedText: ethSpeed > 0
        ? (ethSpeed >= 1000 ? (ethSpeed / 1000).toFixed(ethSpeed % 1000 === 0 ? 0 : 1) + " Gb/s" : ethSpeed + " Mb/s")
        : ""

    readonly property bool wifiOn: NetworkState.wifiEnabled
    readonly property var wifiActive: NetworkState.activeNetwork

    readonly property string netzSubText: wired
        ? ("Ethernet"
            + (ethSpeedText.length ? " · " + ethSpeedText : ""))
        : (wifiActive ? ((wifiActive.name || "") + " · " + Math.round(wifiActive.signalStrength * 100) + "%") : (wifiOn ? "Not connected" : "Off"))

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevices: Bluetooth.devices.values
    readonly property var btConnected: btDevices.filter(function(d) { return d && d.connected })
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false
    readonly property var btPrimary: btConnected.length > 0 ? btConnected[0] : null
    readonly property int btBattery: btPrimary && btPrimary.batteryAvailable ? Math.round(btPrimary.battery * 100) : -1

    readonly property string btSubText: !btOn ? "Off"
        : (btPrimary
            ? ((btPrimary.deviceName || btPrimary.name || "Unknown")
                + (btBattery >= 0 ? " · " + btBattery + "%" : "")
                + (btConnected.length > 1 ? " +" + (btConnected.length - 1) : ""))
            : "Not connected")

    function back() {
        if (subview !== "main") {
            subview = "main";
            return true;
        }
        return false;
    }

    onActiveChanged: if (active) subview = "main"

    Column {
        id: mainCol
        width: parent.width
        spacing: 6 * root.s
        visible: root.subview === "main"
        SectionHeader {
            width: parent.width; s: root.s
            text: "LINK"
        }
        SettingRow {
            width: parent.width; s: root.s
            titleSize: 12; subtitleSize: 10
            showChevron: true
            text: "Network"; subtitle: root.netzSubText; glyph: root.wired ? "settings_ethernet" : "wifi"
            toggleVisible: !root.wired; checked: root.wifiOn
            onSwitchRequested: NetworkState.toggleWifi()
            onClicked: root.subview = "wifi"
        }
        SettingRow {
            width: parent.width; s: root.s
            titleSize: 12; subtitleSize: 10
            toggleVisible: true; showChevron: true
            text: "Bluetooth"; subtitle: root.btSubText; glyph: "bluetooth"; checked: root.btOn
            onSwitchRequested: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
            onClicked: root.subview = "bt"
        }
    }
    LinkWifi {
        id: wifiPage
        width: parent.width; s: root.s
        active: root.active && root.subview === "wifi"
        visible: root.subview === "wifi"
        onBack: root.subview = "main"
        onRequestClose: root.requestClose()
    }
    LinkBt {
        id: btPage
        width: parent.width; s: root.s
        active: root.active && root.subview === "bt"
        visible: root.subview === "bt"
        onBack: root.subview = "main"
        onRequestClose: root.requestClose()
    }
}
