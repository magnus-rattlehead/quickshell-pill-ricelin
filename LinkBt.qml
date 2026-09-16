pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import "Singletons"
import "lib/glitch.js" as Glitch


Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    BluetoothController { id: controller; active: root.active }
    readonly property var adapter: controller.adapter
    readonly property var devices: controller.devices
    readonly property var devicesSorted: controller.devicesSorted
    readonly property bool discovering: controller.discovering
    readonly property string pairingAddress: controller.pairingAddress
    readonly property string failedAddress: controller.failedAddress
    function addressOf(d) { return controller.addressOf(d); }
    function pairDevice(d) { controller.pairDevice(d); }
    function startScan() { controller.startScan(); }
    function stopScan() { controller.stopScan(); }
    function toggleAdapter() { controller.toggleAdapter(); }


    property int navIndex: 0
    property string actionFocus: "row"
    property string focusTarget: "list"

    readonly property bool listFocused: focusTarget === "list"
    readonly property var focusTargets: {
        var targets = ["back"];
        if (adapter && adapter.enabled === true)
            targets.push("scan");
        targets.push("toggle");
        if (devicesSorted.length > 0)
            targets.push("list");
        return targets;
    }


    property string expandedAddress: ""

    implicitHeight: listFrame.y + listFrame.height


    function metaFor(d) {
        if (!d) return "";
        var parts = [];
        if (d.connected) parts.push("connected");
        else if (d.paired) parts.push("paired");
        else if (d.scanned) parts.push("discovered");
        if (d.state !== undefined && typeof BluetoothDeviceState !== "undefined") {
            var st = BluetoothDeviceState.toString(d.state);
            if (st && st.length > 0 && parts.indexOf(st.toLowerCase()) === -1) parts.push(st.toLowerCase());
        }
        return parts.join(" · ");
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }


    function activateDevice(d) {
        if (!d)
            return;
        if (d.connected || d.paired) {
            var addr = d.address || "";
            expandedAddress = (addr.length && expandedAddress === addr) ? "" : addr;
            return;
        }
        pairDevice(d);
    }

    function connectDevice(d) { expandedAddress = ""; controller.connectDevice(d); }

    function disconnectDevice(d) { expandedAddress = ""; controller.disconnectDevice(d); }


    function forgetDevice(d) { expandedAddress = ""; controller.forgetDevice(d); }

    function currentDevice() {
        return navIndex >= 0 && navIndex < devicesSorted.length ? devicesSorted[navIndex] : null;
    }

    function currentActionNames() {
        var d = currentDevice();
        if (!d)
            return [];

        var names = ["row"];
        if (expandedAddress === addressOf(d) && (d.connected || d.paired)) {
            names.push("primary");
            names.push("forget");
        }
        return names;
    }

    function normalizeNav() {
        if (devicesSorted.length === 0) {
            navIndex = -1;
            actionFocus = "row";
            return;
        }
        if (navIndex < 0)
            navIndex = 0;
        else if (navIndex >= devicesSorted.length)
            navIndex = devicesSorted.length - 1;

        var names = currentActionNames();
        if (names.indexOf(actionFocus) < 0)
            actionFocus = "row";
    }

    function normalizeFocusTarget() {
        if (!focusTargets || focusTargets.length === 0) {
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
        if (navIndex < 0)
            return;
        var maxY = Math.max(0, devFlick.contentHeight - devFlick.height);
        if (maxY <= 0) {
            devFlick.contentY = 0;
            return;
        }
        devFlick.contentY = Math.max(0, Math.min(maxY, navIndex * 42 * s - devFlick.height / 2 + 21 * s));
    }

    function moveNav(dir) {
        if (devicesSorted.length === 0)
            return false;
        if (focusTarget !== "list") {
            focusTarget = "list";
            normalizeNav();
            scrollToNav();
            return true;
        }
        normalizeNav();
        navIndex = (navIndex + dir + devicesSorted.length) % devicesSorted.length;
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
        if (!focusTargets || focusTargets.length === 0)
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


    function activateFocused() {
        if (focusTarget === "back") {
            back();
            return true;
        }
        if (focusTarget === "scan") {
            if (discovering)
                stopScan();
            else
                startScan();
            return true;
        }
        if (focusTarget === "toggle") {
            toggleAdapter();
            return true;
        }

        normalizeNav();
        var d = currentDevice();
        if (!d)
            return false;

        if (actionFocus === "primary") {
            if (d.connected)
                disconnectDevice(d);
            else
                connectDevice(d);
            return true;
        }
        if (actionFocus === "forget") {
            forgetDevice(d);
            return true;
        }
        activateDevice(d);
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


    onActiveChanged: {
        if (active) {
            normalizeFocusTarget();
            normalizeNav();
            scrollToNav();
        } else {
            stopScan();
            focusTarget = "list";
            expandedAddress = "";
        }
    }
    onDevicesSortedChanged: {
        normalizeFocusTarget();
        normalizeNav();
    }
    onExpandedAddressChanged: normalizeNav()

    Connections {
        target: root.adapter
        function onEnabledChanged() {
            root.normalizeFocusTarget();
            root.normalizeNav();
        }
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

                ButtonSurface {
                    outlined: root.headerFocused("back")
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    radius: 3 * root.s
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
                    onEntered: Glitch.hover(root)
                    onClicked: { Glitch.click(root); root.back(); }
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "BLUETOOTH"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            ButtonSurface {
                outlined: root.headerFocused("scan")
                anchors.verticalCenter: parent.verticalCenter
                visible: root.adapter ? root.adapter.enabled === true : false
                width: scanLabel.implicitWidth + 12 * root.s
                height: 20 * root.s
                radius: 3 * root.s
                Text {
                    textFormat: Text.PlainText
                    id: scanLabel
                    anchors.centerIn: parent
                    text: root.discovering ? "Scanning…" : "Scan"
                    color: root.discovering ? Theme.vermLit : (scanArea.containsMouse || root.headerFocused("scan") ? Theme.cream : Theme.dim)
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: scanArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: Glitch.hover(root)
                    onClicked: { Glitch.click(root);
                        if (root.discovering)
                            root.stopScan();
                        else
                            root.startScan();
                    }
                }
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.adapter ? root.adapter.enabled === true : false
                focused: root.headerFocused("toggle")
                onToggled: root.toggleAdapter()
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
        height: root.devices.length > 0 ? Math.min(devCol.implicitHeight, 200 * root.s) : 24 * root.s
        readonly property bool scrollable: root.devices.length > 0 && devCol.implicitHeight > height + 1

        Text {
            textFormat: Text.PlainText
            visible: root.devices.length === 0
            anchors.centerIn: parent
            text: root.discovering ? "Scanning…" : "No devices found"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
        }

        Flickable {
            id: devFlick
            visible: root.devices.length > 0
            anchors.fill: parent
            contentHeight: devCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: devCol
                width: devFlick.width - (listFrame.scrollable ? 8 * root.s : 0)
                spacing: 2 * root.s

                Repeater {
                    model: root.devicesSorted

                    Column {
                        id: devItem
                        required property int index
                        required property var modelData
                        readonly property bool isConnected: modelData ? modelData.connected === true : false
                        readonly property bool isPaired: modelData ? modelData.paired === true : false
                        readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
                        readonly property bool pairing: addr.length > 0 && root.pairingAddress === addr
                        readonly property bool failed: addr.length > 0 && root.failedAddress === addr
                        readonly property bool busy: (modelData && typeof BluetoothDeviceState !== "undefined")
                            ? (modelData.state === BluetoothDeviceState.Connecting
                                || modelData.state === BluetoothDeviceState.Disconnecting)
                            : false
                        readonly property bool confirming: addr.length > 0 && root.expandedAddress === addr
                        readonly property int battery: root.batteryLevel(modelData)
                        readonly property bool rowKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "row"
                        readonly property bool primaryKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "primary"
                        readonly property bool forgetKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "forget"
                        width: devCol.width
                        spacing: 2 * root.s

                        ButtonSurface {
                            outlined: devItem.rowKeyFocus
                            width: parent.width
                            height: 38 * root.s
                            radius: 4 * root.s
                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: Glitch.hover(root)
                                onClicked: { Glitch.click(root); root.activateDevice(devItem.modelData); }
                            }

                            Rectangle {
                                id: devTile
                                anchors.left: parent.left
                                anchors.leftMargin: 6 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26 * root.s
                                height: 26 * root.s
                                radius: 4 * root.s
                                color: Theme.tileBg
                                border.width: 1
                                border.color: Theme.border

                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    name: "bluetooth"
                                    color: devItem.isConnected ? Theme.vermLit : Theme.iconDim
                                    stroke: 1.7
                                }
                            }

                            Column {
                                anchors.left: devTile.right
                                anchors.leftMargin: 10 * root.s
                                anchors.right: devRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1 * root.s

                                Text {
                                    textFormat: Text.PlainText
                                    width: parent.width
                                    text: devItem.modelData ? (devItem.modelData.deviceName || devItem.modelData.name || "Unknown") : "Unknown"
                                    color: devItem.isConnected ? Theme.cream : Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 11.5 * root.s
                                    font.weight: devItem.isConnected ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    width: parent.width
                                    visible: text.length > 0
                                    text: root.metaFor(devItem.modelData)
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9.5 * root.s
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: devRight
                                anchors.right: parent.right
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.pairing || devItem.busy
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: Theme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: devItem.pairing || devItem.busy
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                    }
                                }

                                Filament {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.isConnected && devItem.battery >= 0
                                    s: root.s
                                    kind: "battery"
                                    level: Math.max(0, devItem.battery) / 100
                                }

                                ButtonSurface {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !devItem.isPaired && !devItem.pairing
                                    radius: 3 * root.s
                                    height: 18 * root.s
                                    width: pairText.implicitWidth + 16 * root.s
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    Text {
                                        textFormat: Text.PlainText
                                        id: pairText
                                        anchors.centerIn: parent
                                        text: "Pair"
                                        color: pairArea.containsMouse ? Theme.cream : Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: 9.5 * root.s
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: pairArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: Glitch.hover(root)
                                        onClicked: { Glitch.click(root); root.activateDevice(devItem.modelData); }
                                    }
                                }
                            }
                        }

                        Item {
                            visible: devItem.confirming
                            width: parent.width
                            height: 30 * root.s

                            Text {
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: confirmBtns.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: devItem.isConnected ? "Connected" : "Paired"
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

                                ButtonSurface {
                                    outlined: devItem.primaryKeyFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: primaryLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 4 * root.s
                                    Text {
                                        textFormat: Text.PlainText
                                        id: primaryLabel
                                        anchors.centerIn: parent
                                        text: devItem.isConnected ? "Disconnect" : "Connect"
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
                                        onEntered: Glitch.hover(root)
                                        onClicked: { Glitch.click(root); devItem.isConnected
                                            ? root.disconnectDevice(devItem.modelData)
                                            : root.connectDevice(devItem.modelData); }
                                    }
                                }

                                ButtonSurface {
                                    outlined: devItem.forgetKeyFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: forgetLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 4 * root.s
                                    Text {
                                        textFormat: Text.PlainText
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
                                        onEntered: Glitch.hover(root)
                                        onClicked: { Glitch.click(root); root.forgetDevice(devItem.modelData); }
                                    }
                                }
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            visible: devItem.failed
                            text: "Pairing failed"
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 42 * root.s
                        }
                    }
                }
            }
        }

        Rectangle {
            id: devScrollTrack
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
            opacity: root.discovering ? 1 : 0.82

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.max(18 * root.s, parent.height * Math.min(1, devFlick.height / Math.max(1, devFlick.contentHeight)))
                y: (parent.height - height) * (devFlick.contentY / Math.max(1, devFlick.contentHeight - devFlick.height))
                radius: width / 2
                color: root.discovering ? Theme.vermLit : Theme.dim
                opacity: root.discovering ? 0.95 : 0.78
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: devFlick
        }
    }
}
