import QtQuick
import QtQuick.Effects
import "Singletons"


Item {
    id: root

    property real s: 1
    property string title: ""
    property string desc: ""
    property bool show: false
    property string placement: "above"

    readonly property bool below: placement === "below"
    readonly property real pointerH: 5 * s
    readonly property real gap: 5 * s

    property bool armed: false

    width: bubble.width
    height: bubble.height + pointerH
    z: 20

    anchors.horizontalCenter: parent.horizontalCenter
    y: below ? parent.height + gap : -height - gap

    visible: armed || opacity > 0.01
    opacity: armed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.armed ? Motion.standard : Motion.fast } }

    Timer {
        id: delay
        interval: 470
        onTriggered: root.armed = true
    }
    onShowChanged: {
        if (show) {
            delay.restart();
        } else {
            delay.stop();
            armed = false;
        }
    }

    // Keep the anchor in the control's coordinate space, but render the bubble
    // on the window content item, outside the pill's offscreen shader texture.
    function syncOverlay() {
        if (!overlay || !overlay.parent)
            return;
        const point = root.mapToItem(overlay.parent, 0, 0);
        overlay.x = point.x;
        overlay.y = point.y;
        let alpha = 1;
        for (let item = root; item && item !== overlay.parent; item = item.parent) {
            if (!item.visible) {
                alpha = 0;
                break;
            }
            alpha *= item.opacity;
        }
        overlay.opacity = alpha;
    }

    onOpacityChanged: syncOverlay()
    onVisibleChanged: {
        if (!visible && parent && !parent.visible) {
            delay.stop();
            armed = false;
        }
        syncOverlay();
    }
    onXChanged: syncOverlay()
    onYChanged: syncOverlay()

    Connections {
        target: root.Window.window
        enabled: root.visible
        function onAfterAnimating() { root.syncOverlay(); }
    }

    Item {
        id: overlay
        parent: root.Window.contentItem
        width: root.width
        height: root.height
        z: 1000
        enabled: false
        visible: root.visible && root.opacity > 0.001
        onParentChanged: root.syncOverlay()
        onVisibleChanged: root.syncOverlay()

        RecessedTile {
            id: bubble
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.below ? root.pointerH : 0
            width: Math.max(titleText.implicitWidth, descText.implicitWidth) + 22 * root.s
            height: column.implicitHeight + 14 * root.s
            radius: 4 * root.s
            border.width: 1
            border.color: Theme.frameBorder
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Column {
            id: column
            anchors.centerIn: bubble
            spacing: 2 * root.s

            Text {
                textFormat: Text.PlainText
                id: titleText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Bold
            }
            Text {
                textFormat: Text.PlainText
                id: descText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.desc.length > 0
                text: root.desc
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
            }
        }

        Canvas {
            width: 11 * root.s
            height: root.pointerH
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.below ? 0 : root.height - height
            onYChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.cardBot;
                ctx.beginPath();
                if (root.below) {
                    ctx.moveTo(0, height);
                    ctx.lineTo(width, height);
                    ctx.lineTo(width / 2, 0);
                } else {
                    ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width / 2, height);
                }
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
