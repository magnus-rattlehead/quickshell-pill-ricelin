import QtQuick
import QtQuick.Controls.Basic

ListView {
    id: list
    signal backgroundClicked()
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    TapHandler {
        onTapped: (point) => {
            var position = list.contentItem.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
            if (list.indexAt(position.x, position.y) < 0)
                list.backgroundClicked();
        }
    }
}
