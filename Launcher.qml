pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
import "lib/fuzzy.js" as Fuzzy
import "lib/safe.js" as Safe
import "lib/glitch.js" as Glitch


PillSurface {
    id: root

    mTop: 15
    mLeft: 11
    mRight: 11
    mBottom: 14

    property string query: ""
    property int selectedIndex: 0
    property var usage: Object.create(null)
    property int workspaceId: 0


    property point lastPointer: Qt.point(-1, -1)

    readonly property string usageFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/launcher-usage.json"

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay) out.push(src[i]);
        return out;
    }
    readonly property int totalCount: allEntries.length
    readonly property var results: Fuzzy.rank(allEntries, query, usage)

    function focusField() { search.input.forceActiveFocus(); }

    function workspacePrefix() {
        return Safe.workspaceId(root.workspaceId) > 0 ? "[workspace " + Safe.workspaceId(root.workspaceId) + "] " : "";
    }

    function launchEntry(entry) {
        var argv = entry ? entry.command : [];
        if (!argv || argv.length === 0) {
            if (entry)
                entry.execute();
            return;
        }

        var cmd = Safe.commandString(argv);
        if (entry.workingDirectory && entry.workingDirectory.length > 0)
            cmd = "cd -- " + Safe.shellQuote(entry.workingDirectory) + " && exec " + cmd;

        Quickshell.execDetached([
            "hyprctl", "--instance", "0", "dispatch",
            "hl.dsp.exec_cmd(" + Safe.luaQuote(root.workspacePrefix() + cmd) + ")"
        ]);
    }

    function mapCategory(raw) {
        const order = [
            ["TerminalEmulator", "Terminal"], ["WebBrowser", "Browser"],
            ["InstantMessaging", "Chat"], ["Audio", "Media"], ["AudioVideo", "Media"],
            ["Video", "Media"], ["Game", "Game"], ["Development", "Dev"],
            ["Graphics", "Graphics"], ["Office", "Office"], ["Settings", "System"],
            ["System", "System"], ["Utility", "Tool"], ["Network", "Net"]
        ];
        const cats = String(raw).split(/[;,]/);
        for (let i = 0; i < order.length; i++)
            if (cats.includes(order[i][0]))
                return order[i][1];
        return "";
    }

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {

        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var entry = results[selectedIndex];
        if (entry) {
            if (entry.id) {
                root.usage[entry.id] = Math.min(Number.MAX_SAFE_INTEGER, (root.usage[entry.id] || 0) + 1);
                usageStore.setText(JSON.stringify(root.usage));
            }
            root.launchEntry(entry);
        }
        root.requestClose();
    }

    onActiveChanged: {
        if (active) {
            query = "";
            search.text = "";
            selectedIndex = 0;
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: {
        if (selectedIndex >= results.length)
            selectedIndex = 0;
    }

    FileView {
        id: usageStore
        path: root.usageFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: root.usage = Safe.usageFromJson(usageStore.text())

    SearchField {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        kanji: "探"
        placeholder: "Search apps"
        counterText: root.results.length + " / " + root.totalCount
        onTextChanged: {
            root.query = text;
            root.selectedIndex = 0;
        }
        onMoved: (d) => root.move(d)
        onAccepted: root.activate()
        onDismissed: root.requestClose()
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }


    Text {
        textFormat: Text.PlainText
        anchors.centerIn: list
        visible: root.results.length === 0
        text: root.query.length ? "No matches" : "No apps found"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
    }

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 5 * root.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.results.length

        delegate: Item {
            id: appRow
            required property int index
            width: list.width
            height: 38 * root.s

            readonly property var entry: root.results[index]
            readonly property bool selected: index === root.selectedIndex
            readonly property string secondary: {
                if (!entry)
                    return "";
                if (entry.genericName && entry.genericName.length > 0)
                    return entry.genericName;
                if (entry.categories && entry.categories.length > 0)
                    return root.mapCategory(entry.categories);
                return "";
            }

            ButtonSurface {
                outlined: appRow.selected
                anchors.fill: parent
                radius: 4 * root.s
                visible: appRow.selected || rowArea.containsMouse
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onEntered: Glitch.hover(root)
                onPositionChanged: (m) => {
                    var g = rowArea.mapToItem(null, m.x, m.y);
                    if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                        root.lastPointer = Qt.point(g.x, g.y);
                        root.selectedIndex = appRow.index;
                    }
                }
                onClicked: (m) => { Glitch.click(root);
                    root.selectedIndex = appRow.index;
                    root.activate();
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 11 * root.s
                anchors.rightMargin: 11 * root.s

                Rectangle {
                    id: iconBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * root.s
                    height: 22 * root.s
                    radius: 2 * root.s
                    color: Qt.rgba(1, 1, 1, 0.05)
                    visible: !(icon.status === Image.Ready && icon.source != "")
                }
                Image {
                    id: icon
                    anchors.fill: iconBg
                    sourceSize.width: Math.round(40 * root.s)
                    sourceSize.height: Math.round(40 * root.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: {
                        if (!appRow.entry || !appRow.entry.icon)
                            return "";
                        var ic = appRow.entry.icon;
                        return Quickshell.iconPath(ic, true);
                    }
                }

                TextMetrics {
                    id: retMetrics
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    text: "↵"
                }
                Text {
                    textFormat: Text.PlainText
                    id: ret
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: retMetrics.text
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    visible: appRow.selected
                    width: visible ? retMetrics.advanceWidth + 6 * root.s : 0
                    horizontalAlignment: Text.AlignRight
                }


                Column {
                    anchors.left: iconBg.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: ret.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Item {
                        width: parent.width
                        height: nameText.implicitHeight

                        Text {
                            textFormat: Text.PlainText
                            id: nameText
                            anchors.fill: parent
                            text: appRow.entry ? appRow.entry.name : ""
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                            font.weight: appRow.selected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                    }
                    Text {
                        textFormat: Text.PlainText
                        id: sec
                        width: parent.width
                        visible: appRow.secondary.length > 0
                        text: appRow.secondary
                        color: appRow.selected ? Theme.dim : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    WheelScroller {
        anchors.fill: list
        s: root.s
        flick: list
    }

}
