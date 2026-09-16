import QtQuick

Item {
    id: feedback

    property bool effectsEnabled: true
    property real hoverStrength: 0
    property real clickStrength: 0
    property real time: 0
    property double lastHover: -1000
    property double lastClick: -1000
    readonly property bool active: effectsEnabled && (hoverStrength > 0 || clickStrength > 0)

    function trigger(click) {
        if (!effectsEnabled)
            return;
        const now = Date.now();
        if (click) {
            // A button's signal and its MouseArea may report the same action.
            if (now - lastClick < 16) return;
            lastClick = now;
            hoverBurst.stop();
            hoverStrength = 0;
            clickBurst.restart();
        } else {
            if (now - lastHover < 16 || clickStrength > 0) return;
            lastHover = now;
            hoverBurst.restart();
        }
    }

    onEffectsEnabledChanged: if (!effectsEnabled) {
        hoverBurst.stop();
        clickBurst.stop();
        hoverStrength = 0;
        clickStrength = 0;
    }

    NumberAnimation {
        id: hoverBurst
        target: feedback
        property: "hoverStrength"
        from: 1
        to: 0
        duration: 180
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: clickBurst
        target: feedback
        property: "clickStrength"
        from: 1
        to: 0
        duration: 360
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        target: feedback
        property: "time"
        from: 0
        to: 3600
        duration: 3600000
        loops: Animation.Infinite
        running: true
        paused: !feedback.active
    }
}
