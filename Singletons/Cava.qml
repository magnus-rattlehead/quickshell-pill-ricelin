// CAVA process/subscriber pattern adapted from Noctalia v4.4.0 (MIT).
// Copyright (c) 2025 noctalia-dev.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int barsCount: 8
    property var values: Array(barsCount).fill(0)
    property bool playbackActive: false
    property int subscribers: 0
    property int failures: 0
    readonly property bool wanted: playbackActive || subscribers > 0
    onWantedChanged: if (!wanted) {
        retry.stop();
        failures = 0;
    }

    function subscribe() {
        if (!process.running)
            failures = 0;
        subscribers++;
    }

    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    function acceptFrame(data) {
        if (!process.running)
            return;
        const parts = data.trim().split(";");
        if (parts.length < barsCount)
            return;
        const next = [];
        for (let i = 0; i < barsCount; i++) {
            const value = Number(parts[i]);
            if (parts[i] === "" || !Number.isFinite(value) || value < 0 || value > 100)
                return;
            next.push(value / 100);
        }
        failures = 0;
        if (next.some((value, index) => value !== values[index]))
            values = next;
    }

    Timer {
        id: retry
        interval: 2000
    }

    Process {
        id: process
        running: root.wanted && root.failures < 3 && !retry.running
        command: ["cava", "-p", decodeURIComponent(Qt.resolvedUrl("../assets/cava.conf").toString().replace(/^file:\/\//, ""))]
        environment: ({ "PIPEWIRE_LATENCY": "2400/48000" })

        onRunningChanged: if (!running) root.values = Array(root.barsCount).fill(0)
        onExited: () => {
            if (root.wanted) {
                root.failures++;
                retry.restart();
            }
        }
        stdout: SplitParser {
            onRead: data => root.acceptFrame(data)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("CAVA:", text.trim())
        }
    }
}
