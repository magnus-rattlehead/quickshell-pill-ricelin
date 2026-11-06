//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""

    // Prepare spectrum data before the media panel opens.
    Binding {
        target: Cava
        property: "playbackActive"
        value: Players.playing
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Native events handle normal updates; moves can leave derived state stale.
            if (event.name === "movewindowv2" || event.name === "moveworkspacev2")
                Hyprland.refreshWorkspaces();
            if (event.name === "moveworkspacev2")
                Hyprland.refreshMonitors();
        }
    }

    function monitorName(mon) {
        if (!mon || mon.length === 0)
            mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        return mon;
    }

    function toggleSurface(mon, surface) {
        mon = root.monitorName(mon);
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
    }

    function hideAll() {
        root.close();
        for (var monitor of monitors.instances) monitor.hide();
    }

    function peek(mon) {
        mon = root.monitorName(mon);
        var monitor = monitors.instances.find(m => m.modelData.name === mon);
        if (!monitor) return;
        if ((root.openMon === mon && root.openSurface.length > 0) || monitor.pinned) {
            root.hideAll();
        } else {
            root.close();
            monitor.pinned = true;
        }
    }

    GlobalShortcut { appid: "quickshell"; name: "pillPeek"; onPressed: root.peek("") }
    GlobalShortcut { appid: "quickshell"; name: "pillLauncher"; onPressed: root.toggleSurface("", "launcher") }
    GlobalShortcut { appid: "quickshell"; name: "pillClipboard"; onPressed: root.toggleSurface("", "clipboard") }
    GlobalShortcut { appid: "quickshell"; name: "pillPower"; onPressed: root.toggleSurface("", "power") }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function power(mon: string): void { root.toggleSurface(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function notifications(mon: string): void { root.toggleSurface(mon, "notifications"); }
        function media(mon: string): void {
            if (Players.list.length > 0)
                root.toggleSurface(mon, "media");
        }
        function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function system(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.hideAll(); }
        function page(mon: string, name: string): void {
            if (name === "system") name = "sysmon";
            if (Object.prototype.hasOwnProperty.call(Config.pages, name))
                root.toggleSurface(mon, name);
        }
    }

    Variants {
        id: monitors
        model: Quickshell.screens

        Scope {
            id: monitor
            required property var modelData
            readonly property real s: Config.baseScale * Math.max(0.5, Flags.uiScale)
            readonly property var hyprMonitor: Hyprland.monitors.values.length > 0 ? Hyprland.monitorFor(modelData) : null
            readonly property bool fullscreen: hyprMonitor?.activeWorkspace?.hasFullscreen ?? false

            property bool pinned: false
            property bool hovered: false
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool userVisible: surfaceOpen || pinned || hovered
            readonly property bool shellShown: userVisible || pill.toastActive
            readonly property bool modal: surfaceOpen || pinned

            function enter() { clearHover.stop(); hovered = true; }
            function hide() { clearHover.stop(); pinned = false; hovered = false; }
            Timer {
                id: clearHover
                interval: 260
                onTriggered: monitor.hovered = !monitor.fullscreen && (pillHover.hovered || edgeHoverArea.containsMouse || triggerHover.containsMouse)
            }
            onSurfaceOpenChanged: if (surfaceOpen) {
                pinned = false;
                Notifs.popup = null;
                focusScope.forceActiveFocus();
            }
            onUserVisibleChanged: if (userVisible) focusScope.forceActiveFocus()
            onFullscreenChanged: if (fullscreen) {
                if (root.openMon === modelData.name) root.close();
                hide();
            }

            PanelWindow {
                id: edgeTrigger
                screen: monitor.modelData
                visible: !monitor.fullscreen && root.openSurface.length === 0
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "pill-edge-trigger"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors { top: true; left: true; right: true }
                implicitHeight: Math.max(4, 4 * monitor.s)

                mask: edgeRegion
                Region {
                    id: edgeRegion
                    readonly property real triggerW: Math.min(edgeTrigger.width, 320 * monitor.s)
                    x: (edgeTrigger.width - triggerW) / 2
                    y: 0
                    width: triggerW
                    height: edgeTrigger.height
                }

                MouseArea {
                    id: triggerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: monitor.enter()
                    onExited: clearHover.restart()
                }
            }

            PanelWindow {
                id: overlay
                readonly property real topGap: 8 * Flags.topGap * monitor.s
                readonly property bool edgeHoverable: !monitor.fullscreen && !monitor.modal && root.openSurface.length === 0

                screen: monitor.modelData
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: monitor.userVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
                WlrLayershell.namespace: "pill"

                anchors { top: true; left: true; right: true; bottom: true }

                mask: monitor.fullscreen ? hiddenRegion : (monitor.modal ? fullRegion : (monitor.shellShown ? overlayRevealRegion : overlayEdgeRegion))
                Region { id: hiddenRegion }
                Region {
                    id: overlayEdgeRegion
                    readonly property real triggerW: Math.min(overlay.width, Math.max(320 * monitor.s, pill.targetW))
                    x: (overlay.width - triggerW) / 2
                    y: 0
                    width: triggerW
                    height: Math.max(8, 8 * monitor.s)
                }
                Region {
                    id: overlayRevealRegion
                    readonly property real baseW: Math.max(pill.width, pill.targetW)
                    readonly property real triggerW: Math.min(overlay.width, Math.max(baseW, 320 * monitor.s))
                    x: (overlay.width - triggerW) / 2
                    y: 0
                    width: triggerW
                    height: Math.max(pill.y + Math.max(pill.height, pill.targetH), overlayEdgeRegion.height)
                }
                Region {
                    id: fullRegion
                    width: overlay.width
                    height: overlay.height
                }

                MouseArea {
                    id: edgeHoverArea
                    x: overlayRevealRegion.x
                    y: overlayRevealRegion.y
                    width: overlayRevealRegion.width
                    height: overlayRevealRegion.height
                    enabled: overlay.edgeHoverable
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: monitor.enter()
                    onExited: clearHover.restart()
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: monitor.modal
                    acceptedButtons: Qt.AllButtons
                    onPressed: {
                        if (monitor.surfaceOpen) {
                            root.close();
                        } else {
                            monitor.pinned = false;
                        }
                    }
                }

                FocusScope {
                    id: focusScope
                    anchors.fill: parent
                    focus: monitor.userVisible

                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Escape) {
                            if (pill.surfaceOpen) {
                                if (!pill.linkBack())
                                    root.close();
                            } else {
                                root.hideAll();
                            }
                            e.accepted = true;
                            return;
                        }
                    }
                    Pill {
                        id: pill
                        anchors.top: parent.top
                        anchors.topMargin: overlay.topGap
                        anchors.horizontalCenter: parent.horizontalCenter
                        s: monitor.s
                        hyprMonitor: monitor.hyprMonitor
                        surface: monitor.surface
                        pinned: monitor.pinned
                        mainHovered: monitor.hovered
                        onTogglePinned: monitor.pinned = !monitor.pinned

                        HoverHandler {
                            id: pillHover
                            enabled: !monitor.fullscreen && monitor.shellShown
                            onHoveredChanged: if (hovered) monitor.enter(); else clearHover.restart();
                        }

                        opacity: (monitor.fullscreen || !monitor.shellShown) ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
                        transform: Translate {
                            y: (monitor.fullscreen || !monitor.shellShown) ? -(pill.height + overlay.topGap) : 0
                            Behavior on y { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
                        }

                        onRequestSurface: (name) => root.toggleSurface(monitor.modelData.name, name)
                        onRequestClose: root.close()
                    }
                }

            }
        }
    }
}
