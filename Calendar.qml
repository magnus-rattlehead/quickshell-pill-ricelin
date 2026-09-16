pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"
import "lib/glitch.js" as Glitch

PillSurface {
    id: root

    mTop: 16
    mLeft: 18
    mRight: 18
    mBottom: 16

    readonly property var loc: Qt.locale("en_US")

    readonly property date today: sysClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property int offset: firstWeekdayOffset(viewYear, viewMonth)
    readonly property int monthLen: daysInMonth(viewYear, viewMonth)
    readonly property int rows: Math.ceil((offset + monthLen) / 7)

    readonly property real cellH: 24 * s
    readonly property real rowGap: 2 * s

    readonly property real gridW: 282 * s
    readonly property real weatherW: 152 * s
    readonly property real gutter: 16 * s

    readonly property real gridHeight: grid.y + rows * cellH + (rows - 1) * rowGap

    implicitWidth: gridW + weatherW + gutter

    implicitHeight: Math.max(gridHeight, weather.implicitHeight)

    readonly property bool todayVisible: viewMonth === today.getMonth()
        && viewYear === today.getFullYear()

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    function firstWeekdayOffset(year, month) {
        var d = new Date(year, month, 1).getDay();
        return (d + 6) % 7;
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function isToday(day) {
        return day === today.getDate()
            && viewMonth === today.getMonth()
            && viewYear === today.getFullYear();
    }


    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;

    }

    function resetToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }


    onActiveChanged: if (active) {
        resetToday();
        Weather.refresh();
    }

    WeatherPane {
        id: weather
        s: root.s
        width: root.weatherW
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        weatherData: Weather
        configuredCity: Flags.weatherCity
        onCitySubmitted: (city) => Flags.weatherCity = city
    }

    Rectangle {
        id: weatherSeam
        anchors.left: weather.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.hair
        visible: true
        opacity: weather.opacity
    }

    Item {
        id: gridPane
        anchors.left: weather.right
        anchors.leftMargin: root.gutter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.gridW

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    textFormat: Text.PlainText
                    id: calGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "暦"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    textFormat: Text.PlainText
                    id: monthLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.loc.standaloneMonthName(root.viewMonth, Locale.LongFormat)
                        + " " + root.viewYear
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.0 * root.s
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s

                Repeater {
                    model: [-1, 1]

                    ButtonSurface {
                        id: nav
                        required property int modelData
                        width: 22 * root.s
                        height: 22 * root.s
                        radius: Motion.rSmall * root.s
                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 16 * root.s
                            height: 16 * root.s
                            name: nav.modelData < 0 ? "chevron-left" : "chevron-right"
                            color: navArea.containsMouse ? Theme.cream : Theme.iconDim
                            stroke: 1.8
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: Glitch.hover(root)
                            onClicked: { Glitch.click(root); root.shiftMonth(nav.modelData); }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: divider
            anchors.top: header.bottom
            anchors.topMargin: 9 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
        }

        Row {
            id: weekdays
            anchors.top: divider.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right

            Repeater {
                model: 7

                Item {
                    id: wd
                    required property int index
                    readonly property bool weekend: index >= 5
                    width: weekdays.width / 7
                    height: 16 * root.s

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: root.loc.standaloneDayName((wd.index + 1) % 7, Locale.NarrowFormat)
                        color: wd.weekend ? Theme.faint : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5 * root.s
                    }
                }
            }
        }

        Grid {
            id: grid
            y: weekdays.y + weekdays.height + 4 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7
            rowSpacing: root.rowGap
            columnSpacing: 0

            Repeater {
                model: root.rows * 7

                Item {
                    id: cell
                    required property int index
                    readonly property int weekday: index % 7
                    readonly property bool weekend: weekday >= 5
                    width: grid.width / 7
                    height: root.cellH

                    readonly property int dayNum: index - root.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= root.monthLen
                    readonly property bool current: inMonth && root.isToday(dayNum)
                    readonly property int ghostNum: dayNum < 1
                        ? root.daysInMonth(root.viewYear, root.viewMonth - 1) + dayNum
                        : dayNum - root.monthLen

                    ButtonSurface {
                        anchors.centerIn: parent
                        width: 22 * root.s
                        height: 22 * root.s
                        radius: Motion.rSmall * root.s
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24 * root.s
                        height: 24 * root.s
                        radius: Motion.rSmall * root.s
                        visible: cell.current
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.frameBorder
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.dayNum : cell.ghostNum
                        color: cell.inMonth
                            ? (cell.current ? Theme.todayWarm
                                : (cell.weekend ? Theme.subtle : Theme.cream))
                            : Theme.ghost
                        opacity: cell.inMonth && !cell.current && !cell.weekend ? 0.85 : 1.0
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: cell.current ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }


                }
            }
        }


    }


}
