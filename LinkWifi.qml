pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import "Singletons"
import "lib/glitch.js" as Glitch


Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    WifiController {
        id: controller
        active: root.active
        onConnected: { root.expandedSsid = ""; root.pwDraft = ""; }
    }
    readonly property var wifiDev: controller.wifiDev
    readonly property bool wifiOn: controller.wifiOn
    readonly property var nets: controller.nets
    readonly property var netsSorted: controller.netsSorted
    readonly property var activeNet: controller.activeNet
    readonly property string statusText: controller.statusText
    readonly property var knownProfiles: controller.knownProfiles
    readonly property bool connecting: controller.connecting
    readonly property bool connectFailed: controller.connectFailed
    readonly property bool scanning: controller.scanning
    readonly property string revealedSsid: controller.revealedSsid
    readonly property string revealedPw: controller.revealedPw
    readonly property bool revealResolved: controller.revealResolved

    function refresh() { controller.refresh(); }
    function isSecured(ssid) { return controller.isSecured(ssid); }
    function toggleWifi() { controller.toggleWifi(); }
    function startScan() { controller.startScan(); }
    function stopScan() { controller.stopScan(); }
    function hidePassword() { controller.hidePassword(); }
    function revealPassword(ssid) { controller.revealPassword(ssid); }
    function connectWithPassword(ssid, pw) {
        controller.connectWithPassword(ssid, pw);
        root.pwDraft = "";
    }
    function connectKnown(net) { root.expandedSsid = ""; controller.connectKnown(net); }
    function disconnectNetwork(net) { root.expandedSsid = ""; controller.disconnectNetwork(net); }
    function forgetNetwork(ssid) { root.expandedSsid = ""; controller.forgetNetwork(ssid); }


    property string expandedSsid: ""
    property int navIndex: 0
    property string actionFocus: "row"
    property string focusTarget: "list"


    property string pwDraft: ""

    readonly property int netCount: netsSorted.length
    readonly property int rowCount: netCount
    readonly property bool listFocused: focusTarget === "list"
    readonly property var focusTargets: {
        var targets = ["back"];
        if (wifiOn)
            targets.push("scan");
        targets.push("toggle");
        if (rowCount > 0)
            targets.push("list");
        return targets;
    }

    implicitHeight: listFrame.y + listFrame.height


    function activateNetwork(net) {
        if (!net)
            return;
        var ssid = net.name || "";
        if (expandedSsid === ssid && ssid.length) {
            expandedSsid = "";
            return;
        }
        if (net.connected || !!knownProfiles[ssid]) {
            pwDraft = "";
            expandedSsid = ssid;
            return;
        }
        if (!isSecured(ssid)) {
            expandedSsid = "";
            controller.connectKnown(net);
            refresh();
            return;
        }
        controller.connectFailed = false;
        pwDraft = "";
        expandedSsid = ssid;
    }


    function currentNet() {
        return navIndex >= 0 && navIndex < netCount ? netsSorted[navIndex] : null;
    }

    function currentActionNames() {

        var net = currentNet();
        if (!net)
            return [];

        var names = ["row"];
        var ssid = net.name || "";
        if (expandedSsid === ssid && (net.connected || !!knownProfiles[ssid])) {
            names.push("primary");
            if (knownProfiles[ssid]) {
                names.push("reveal");
                names.push("forget");
            }
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


    onActiveChanged: {
        if (active) {
            refresh();
            normalizeFocusTarget();
            normalizeNav();
            scrollToNav();
        } else {
            stopScan();
            focusTarget = "list";
            expandedSsid = "";
            hidePassword();
            pwDraft = "";
        }
    }

    onWifiOnChanged: {
        if (!wifiOn)
            stopScan();
        normalizeFocusTarget();
        normalizeNav();
    }

    onExpandedSsidChanged: {
        pwDraft = "";
        if (revealedSsid !== expandedSsid)
            hidePassword();
        normalizeNav();
    }
    onRowCountChanged: {
        normalizeFocusTarget();
        normalizeNav();
    }
    onKnownProfilesChanged: normalizeNav()

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
                text: "WIFI"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }

            Text {
                textFormat: Text.PlainText
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

                ButtonSurface {
                    outlined: root.headerFocused("scan")
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    radius: 3 * root.s
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
                    onEntered: Glitch.hover(root)
                    onClicked: { Glitch.click(root); root.scanning ? root.stopScan() : root.startScan(); }
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
            textFormat: Text.PlainText
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
                        readonly property bool known: !!root.knownProfiles[ssid]
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

                        ButtonSurface {
                            outlined: netItem.rowKeyFocus
                            width: parent.width
                            height: 30 * root.s
                            radius: 4 * root.s
                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: Glitch.hover(root)
                                onClicked: { Glitch.click(root); root.activateNetwork(netItem.modelData); }
                            }

                            Text {
                                textFormat: Text.PlainText
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
                                textFormat: Text.PlainText
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

                                ButtonSurface {
                                    outlined: netItem.primaryKeyFocus
                                    id: primaryBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: primaryLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 4 * root.s
                                    Text {
                                        textFormat: Text.PlainText
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
                                        onEntered: Glitch.hover(root)
                                        onClicked: { Glitch.click(root); netItem.isActive
                                            ? root.disconnectNetwork(netItem.modelData)
                                            : root.connectKnown(netItem.modelData); }
                                    }
                                }

                                ButtonSurface {
                                    outlined: netItem.revealKeyFocus
                                    id: revealBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: netItem.known
                                    readonly property bool shown: root.revealedSsid === netItem.ssid
                                    width: revealLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 4 * root.s
                                    Text {
                                        textFormat: Text.PlainText
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
                                        onEntered: Glitch.hover(root)
                                        onClicked: { Glitch.click(root); root.revealPassword(netItem.ssid); }
                                    }
                                }

                                ButtonSurface {
                                    outlined: netItem.forgetKeyFocus
                                    id: forgetBtn
                                    visible: netItem.known
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
                                        onClicked: { Glitch.click(root); root.forgetNetwork(netItem.ssid); }
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
                                textFormat: Text.PlainText
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
                                textFormat: Text.PlainText
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
                                text: netItem.asking ? root.pwDraft : ""
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
                                        onEntered: Glitch.hover(root)
                                        onClicked: { Glitch.click(root); root.connectWithPassword(netItem.ssid, pwField.text); }
                                    }
                                }
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
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

}
