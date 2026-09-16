import QtQuick
import Quickshell
import "@PILL@" as Pill
import "@PILL@/Singletons" as Services

ShellRoot {
    id: testRoot
    property int phase: 0
    property int ticks: 0
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    Item {
        width: 900; height: 700
        Pill.Calendar { id: calendar; open: true }
        Pill.Launcher { id: launcher }
        Pill.Clipboard {}
        Pill.Link { id: link; open: true }
        Pill.LinkWifi { active: true }
        Pill.LinkBt { active: true }
        Pill.Mixer { open: true }
        Pill.Media {}
        Pill.Power { id: power }
        Pill.SysmonSurface {}
        Pill.Pill { id: pill; screenName: "test-monitor" }
        Pill.WifiController { id: wifi; active: true }
        Pill.BluetoothController { id: bluetooth }
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            try {
                testRoot.ticks++;
                testRoot.check(testRoot.ticks < 100, "timed out in phase " + testRoot.phase);
                if (testRoot.phase === 0) {
                    Services.Sysmon.open = true;
                    var config = Qt.createComponent("@SHELL@");
                    // Offscreen Qt cannot load Quickshell's Wayland PanelWindow backend.
                    testRoot.check(config.status === Component.Ready || config.errorString().indexOf("No PanelWindow backend loaded") !== -1, config.errorString());
                    testRoot.check(calendar.daysInMonth(2024, 1) === 29, "leap February");
                    testRoot.check(calendar.daysInMonth(2025, 1) === 28, "ordinary February");
                    calendar.viewYear = 2025; calendar.viewMonth = 11; calendar.shiftMonth(1);
                    testRoot.check(calendar.viewYear === 2026 && calendar.viewMonth === 0, "year rollover");
                    calendar.shiftMonth(-1);
                    testRoot.check(calendar.viewYear === 2025 && calendar.viewMonth === 11, "reverse rollover");
                    calendar.resetToday();
                    link.subview = "wifi";
                    link.keyPress(Qt.Key_Tab, false);
                    testRoot.check(link.back(), "network page back navigation");
                    link.subview = "bt";
                    link.keyPress(Qt.Key_Tab, false);
                    link.back();
                    testRoot.check(calendar.todayVisible, "today highlight");
                    testRoot.check(calendar.implicitWidth > 282 && calendar.implicitHeight > 0, "weather setup remains visible");
                    launcher.query = "1+2";
                    testRoot.check(launcher.calc === undefined, "calculator removed");
                    Services.Notifs.history = ["constructor", "__proto__", "toString"].map(function(app, i) {
                        return {app:app,id:"test"+i,summary:"literal <b>text</b>",body:"hello",ts:Date.now(),urgency:1};
                    });
                    testRoot.check(Services.Notifs.groups.length === 3, "prototype-safe notification groups");
                    Services.Notifs.toggleExpanded("__proto__");
                    testRoot.check(Services.Notifs.expandedApps["__proto__"] === true, "prototype-safe expansion state");
                    power.focusIndex = 4;
                    testRoot.check(power.pressFocused(), "immediate power activation");
                    power.focusIndex = -1;
                    testRoot.check(!power.pressFocused(), "no unfocused power activation");
                    bluetooth.pairDevice({address:'00:11:22:33:44:55; exit 1'});
                    testRoot.check(bluetooth.pairingAddress === "", "invalid Bluetooth address rejected");
                    Services.Flags.weatherCity = "Old";
                    testRoot.phase = 1;
                } else if (testRoot.phase === 1) {
                    Services.Flags.weatherCity = "New";
                    testRoot.phase = 2;
                } else if (testRoot.phase === 2 && wifi.knownProfiles["Cafe: back\\slash"]) {
                    wifi.connectWithPassword("Cafe: back\\slash", "literal'$(not-a-command)");
                    testRoot.phase = 3;
                } else if (testRoot.phase === 3 && !wifi.connecting) {
                    testRoot.check(!wifi.connectFailed, "password connection succeeded");
                    wifi.revealPassword("Cafe: back\\slash");
                    testRoot.phase = 4;
                } else if (testRoot.phase === 4) {
                    wifi.hidePassword();
                    testRoot.phase = 5;
                } else if (testRoot.phase === 5 && Services.Weather.ready && Services.Weather.city === "New" && Services.Sysmon.gpus.length === 1 && Services.Sysmon.gpus[0].load === 37) {
                    testRoot.check(wifi.revealedPw === "" && !wifi.revealResolved, "dismissed secret stays cleared");
                    testRoot.check(Services.Weather.lat === 46 && Services.Weather.tempNow === 20, "only new-city forecast accepted");
                    var descriptors = Services.Sysmon.gpuDevices;
                    Services.Sysmon.updateGpu("0000:0b:00.0", {temp:41});
                    testRoot.check(Services.Sysmon.gpuDevices === descriptors, "GPU measurements keep collectors stable");
                    Services.Sysmon.open = false;
                    console.log("PILL_SMOKE_OK");
                    Qt.quit();
                }
            } catch (e) {
                console.error("PILL_SMOKE_FAIL: " + e);
                Qt.quit();
            }
        }
    }
}
