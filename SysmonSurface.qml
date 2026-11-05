pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Singletons"

PillSurface {
    id: root
    topPadding: 14 * s; leftPadding: 16 * s; rightPadding: 16 * s; bottomPadding: 16 * s
    implicitWidth: 360 * s + leftPadding + rightPadding
    contentItem.implicitHeight: content.implicitHeight
    onActiveChanged: Sysmon.open = active
    Component.onDestruction: Sysmon.open = false

    function diskSize(bytes) {
        var gib = bytes / 1073741824;
        return gib >= 1024 ? (gib / 1024).toFixed(1) + " TiB"
            : gib >= 1 ? gib.toFixed(1) + " GiB" : (bytes / 1048576).toFixed(0) + " MiB";
    }

    component Metric: Column {
        id: metric
        property string title: ""
        property string detail: ""
        property real value: 0
        width: content.width
        spacing: 5 * root.s
        RowLayout {
            width: parent.width
            PanelLabel {
                Layout.fillWidth: true
                text: metric.title
                color: Theme.placeholderText
                elide: Text.ElideRight
                font.pixelSize: 10 * root.s
                HoverHandler { id: titleHover }
                ToolTip.visible: titleHover.hovered
                ToolTip.text: metric.title
            }
            PanelLabel {
                Layout.maximumWidth: parent.width * 0.7
                text: metric.detail
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font.pixelSize: 11 * root.s
                font.features: { "tnum": 1 }
            }
        }
        ProgressBar {
            id: bar
            width: parent.width
            height: 4 * root.s
            from: 0; to: 100
            value: Math.max(0, Math.min(100, metric.value))
            background: Rectangle { color: Qt.alpha(Theme.text, 0.12); radius: height / 2 }
            contentItem: Item {
                Rectangle {
                    width: bar.visualPosition * parent.width
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                }
            }
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: 14 * root.s
        SectionHeader {
            width: parent.width; s: root.s; text: "SYSTEM"
            PanelLabel { text: Sysmon.uptime; color: Theme.placeholderText; font.pixelSize: 9 * root.s }
        }
        Metric {
            title: "CPU"
            value: Sysmon.cpu
            detail: Sysmon.cpu + "%" + (Sysmon.cpuTemp >= 0 ? " · " + Sysmon.cpuTemp + "°" : "")
        }
        Repeater {
            model: Sysmon.gpus
            Metric {
                required property var modelData
                title: modelData.shortLabel
                value: modelData.load
                detail: [modelData.load >= 0 ? modelData.load + "%" : "n/a",
                    modelData.temp >= 0 ? modelData.temp + "°" : "",
                    modelData.hasVram ? modelData.vramUsedGb.toFixed(1) + "/" + modelData.vramTotalGb.toFixed(0) + " GB VRAM" : ""]
                    .filter(text => text.length > 0).join(" · ")
            }
        }
        Metric {
            title: "Memory"
            value: Sysmon.memPct
            detail: Sysmon.memUsedGb.toFixed(1) + "/" + Sysmon.memTotalGb.toFixed(1) + " GB · " + Sysmon.memPct + "%"
        }
        Repeater {
            model: Sysmon.disks
            Metric {
                required property var modelData
                title: "Disk · " + modelData.mount
                value: modelData.percent
                detail: root.diskSize(modelData.used) + " / " + root.diskSize(modelData.total) + " · " + modelData.percent + "%"
            }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Theme.text, 0.14) }
        RowLayout {
            width: parent.width
            PanelLabel { text: "Network"; color: Theme.placeholderText; font.pixelSize: 10 * root.s }
            PanelLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: "↓ " + Sysmon.netDown.toFixed(1) + "  ↑ " + Sysmon.netUp.toFixed(1) + " MB/s"
                font.pixelSize: 11 * root.s
            }
        }
        RowLayout {
            width: parent.width
            PanelLabel { text: "Swap"; color: Theme.placeholderText; font.pixelSize: 10 * root.s }
            PanelLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: Sysmon.swapUsedGb.toFixed(1) + " GB"
                font.pixelSize: 11 * root.s
            }
        }
    }
}
