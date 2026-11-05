pragma ComponentBehavior: Bound
import QtQuick

LinkPage {
    id: root
    property string expandedAddress: ""
    BluetoothController { id: controller; active: root.active }
    onActiveChanged: if (!active) expandedAddress = ""

    header.text: "Bluetooth"
    header.actions: [
        PanelButton {
            s: root.s; glyph: "undo"
            tip: controller.discovering ? "Stop scan" : "Scan devices"
            checked: controller.discovering
            enabled: controller.adapter && controller.adapter.enabled
            onClicked: controller.discovering ? controller.stopScan() : controller.startScan()
        },
        LinkToggle {
            s: root.s
            checked: controller.adapter ? controller.adapter.enabled : false
            enabled: controller.adapter !== null
            onToggled: controller.toggleAdapter()
        }
    ]
    list.model: controller.adapter && controller.adapter.enabled ? controller.devicesSorted : []
    list.delegate: Column {
        id: row
        required property var modelData
        width: ListView.view.width
        spacing: 4 * root.s
        SettingRow {
            id: deviceButton
            width: parent.width; height: 42 * root.s; s: root.s
            text: row.modelData.name || row.modelData.deviceName || row.modelData.address
            subtitle: (row.modelData.pairing ? "Pairing…"
                : controller.failedAddress === row.modelData.address ? "Pairing failed"
                : row.modelData.connected ? "Connected" : row.modelData.paired ? "Paired" : "Discovered")
                + (row.modelData.batteryAvailable ? " · " + Math.round(row.modelData.battery * 100) + "%" : "")
            highlighted: row.modelData.connected
            onClicked: {
                if (!row.modelData.paired && !row.modelData.connected) controller.pairDevice(row.modelData);
                else root.expandedAddress = root.expandedAddress === row.modelData.address ? "" : row.modelData.address;
            }
        }
        Row {
            visible: root.expandedAddress === row.modelData.address
            spacing: 4 * root.s
            PanelButton {
                s: root.s; text: row.modelData.connected ? "Disconnect" : "Connect"
                onClicked: {
                    if (row.modelData.connected) row.modelData.disconnect();
                    else row.modelData.connect();
                    root.expandedAddress = "";
                }
            }
            PanelButton {
                s: root.s; text: "Forget"
                onClicked: { row.modelData.forget(); root.expandedAddress = ""; }
            }
        }
    }
    emptyText: !controller.adapter ? "No Bluetooth adapter" : controller.adapter.enabled ? "No devices found" : "Bluetooth is off"
}
