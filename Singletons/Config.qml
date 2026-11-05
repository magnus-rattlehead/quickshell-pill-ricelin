pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Keep the existing preferences path. Change this for an independent profile.
    readonly property string storageName: "ricelin"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/" + storageName
    readonly property string font: defaultFont.font.family
    FontMetrics { id: defaultFont }
    readonly property string locale: Qt.locale().name
    // Global size for the pill, fonts, icons, and spacing.
    readonly property real baseScale: 1.5
    readonly property string timeFormat: "hh:mm"
    readonly property string timeFormatSeconds: "hh:mm:ss"

    readonly property var pages: ({
        mixer: "Mixer.qml", calendar: "Calendar.qml", launcher: "Launcher.qml",
        clipboard: "Clipboard.qml", power: "Power.qml", media: "Media.qml",
        link: "Link.qml", notifications: "NotificationsSurface.qml", sysmon: "SysmonSurface.qml"
    })

    // Argument arrays, not shell strings. An empty array disables an action.
    readonly property list<string> lockCommand: ["loginctl", "lock-session"]
    readonly property list<string> suspendCommand: ["loginctl", "suspend"]
    readonly property list<string> rebootCommand: ["loginctl", "reboot"]
    readonly property list<string> shutdownCommand: ["loginctl", "poweroff"]
    // The Wayland idle inhibitor also runs; this command additionally blocks sleep.
    readonly property list<string> inhibitCommand: ["systemd-inhibit", "--what=idle:sleep",
        "--who=Quickshell pill", "--why=keep awake", "--mode=block", "sleep", "infinity"]
}
