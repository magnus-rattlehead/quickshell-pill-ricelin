pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "Singletons"

PillSurface {
    id: root
    topPadding: 16 * s; leftPadding: 18 * s; rightPadding: 18 * s; bottomPadding: 16 * s
    readonly property var loc: Qt.locale(Config.locale)
    readonly property date today: sysClock.date
    readonly property bool todayVisible: grid.month === today.getMonth() && grid.year === today.getFullYear()
    readonly property real gridW: 282 * s
    implicitWidth: gridW + leftPadding + rightPadding
    contentItem.implicitHeight: gridPane.implicitHeight
    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    function shiftMonth(delta) {
        var date = new Date(grid.year, grid.month + delta, 1);
        grid.year = date.getFullYear();
        grid.month = date.getMonth();
    }
    function resetToday() { grid.year = today.getFullYear(); grid.month = today.getMonth(); }
    onActiveChanged: if (active) resetToday()
    Column {
        id: gridPane
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.gridW
        spacing: 6 * root.s
        RowLayout {
            width: parent.width
            height: 28 * root.s
            PanelLabel {
                Layout.fillWidth: true
                text: grid.title
                font.pixelSize: 12 * root.s
            }
            PanelButton { s: root.s; text: "Today"; enabled: !root.todayVisible; onClicked: root.resetToday() }
            PanelButton { s: root.s; glyph: "chevron_left"; tip: "Previous month"; onClicked: root.shiftMonth(-1) }
            PanelButton { s: root.s; glyph: "chevron_right"; tip: "Next month"; onClicked: root.shiftMonth(1) }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Theme.text, 0.14) }
        DayOfWeekRow {
            width: parent.width
            height: 16 * root.s
            locale: root.loc
            delegate: PanelLabel {
                required property var model
                text: model.narrowName
                horizontalAlignment: Text.AlignHCenter
                color: Theme.placeholderText
                font.pixelSize: 9 * root.s
            }
        }
        MonthGrid {
            id: grid
            width: parent.width
            height: 6 * 24 * root.s + 5 * spacing
            spacing: 2 * root.s
            month: root.today.getMonth()
            year: root.today.getFullYear()
            locale: root.loc
            delegate: Rectangle {
                required property var model
                readonly property bool inMonth: model.month === grid.month
                color: model.today ? Qt.alpha(Theme.midlight, 0.65) : "transparent"
                radius: 4 * root.s
                border.width: model.today ? 1 : 0
                border.color: Qt.alpha(Theme.mid, 0.45)
                PanelLabel {
                    anchors.centerIn: parent
                    text: parent.model.day
                    color: !parent.inMonth ? Theme.midlight : parent.model.today ? Theme.accent : Theme.text
                    font.pixelSize: 11 * root.s
                    font.weight: parent.model.today ? Font.DemiBold : Font.Normal
                }
            }
        }
    }
}
