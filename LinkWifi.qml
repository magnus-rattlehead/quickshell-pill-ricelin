pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import "Singletons"

LinkPage {
    id: root
    property string expandedSsid: ""
    property string pwDraft: ""

    WifiController {
        id: controller
        active: root.active
        onConnected: root.expandedSsid = ""
    }
    onActiveChanged: if (!active) { expandedSsid = ""; pwDraft = ""; }
    onExpandedSsidChanged: pwDraft = ""

    header.text: controller.statusText
    header.actions: LinkToggle { s: root.s; checked: controller.wifiOn; onToggled: NetworkState.toggleWifi() }
    list.model: controller.wifiOn ? controller.netsSorted : []
    list.delegate: Column {
        id: row
        required property var modelData
        readonly property string ssid: modelData.name
        readonly property bool expanded: root.expandedSsid === ssid
        width: ListView.view.width
        spacing: 4 * root.s
        SettingRow {
            id: networkButton
            width: parent.width; height: 38 * root.s; s: root.s
            glyph: "wifi"
            glyphColor: row.modelData.connected ? Theme.text : Theme.highlight
            text: row.ssid
            detail: Math.round(row.modelData.signalStrength * 100) + "%" + (controller.isSecured(row.modelData) ? " · secured" : "")
            highlighted: row.modelData.connected
            onClicked: {
                if (row.expanded) root.expandedSsid = "";
                else if (!row.modelData.known && !controller.isSecured(row.modelData)) controller.connectNetwork(row.modelData);
                else root.expandedSsid = row.ssid;
            }
        }
        Column {
            width: parent.width
            spacing: 4 * root.s
            visible: row.expanded
            TextField {
                id: password
                width: parent.width
                visible: !row.modelData.known && !row.modelData.connected
                echoMode: TextInput.Password
                text: row.expanded ? root.pwDraft : ""
                placeholderText: "Password"
                color: Theme.text
                font.pixelSize: 11 * root.s
                selectByMouse: true
                background: Rectangle { color: Theme.base; radius: 4 * root.s; border.color: Theme.midlight }
                onTextEdited: root.pwDraft = text
                function submit() { controller.connectNetwork(row.modelData, root.pwDraft); root.pwDraft = ""; }
                onAccepted: submit()
                onVisibleChanged: if (visible && row.expanded) forceActiveFocus()
            }
            Flow {
                width: parent.width
                spacing: 4 * root.s
                PanelButton {
                    s: root.s
                    text: row.modelData.connected ? "Disconnect" : "Connect"
                    enabled: !controller.connecting
                    onClicked: {
                        if (row.modelData.connected) row.modelData.disconnect();
                        else if (row.modelData.known) controller.connectNetwork(row.modelData);
                        else password.submit();
                    }
                }
                PanelButton {
                    s: root.s; text: "Forget"
                    visible: !!controller.knownProfiles[row.ssid]
                    onClicked: { controller.forgetNetwork(row.ssid); root.expandedSsid = ""; }
                }
            }
            PanelLabel {
                width: parent.width
                visible: controller.connectFailed || controller.connecting
                text: controller.connectFailed ? "Connection failed" : "Connecting…"
                wrapMode: Text.WrapAnywhere
                color: Theme.placeholderText
                font.pixelSize: 10 * root.s
            }
        }
    }
    emptyText: !controller.wifiDev ? "No Wi-Fi device" : controller.wifiOn ? "No networks found" : "Wi-Fi is off"
}
