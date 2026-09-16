import QtQuick
import "Singletons"
import "lib/glitch.js" as Glitch

// Visual background only. Existing controls own click/drag/key handling.
Rectangle {
    id: surface

    property bool outlined: false

    color: "transparent"
    border.width: pointer.hovered || outlined ? 1 : 0
    border.color: outlined ? Theme.accent : Qt.alpha(Theme.accent, 0.65)

    HoverHandler {
        id: pointer
        onHoveredChanged: if (hovered) Glitch.hover(surface)
    }
}
