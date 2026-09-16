pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"
import "lib/glitch.js" as Glitch

Item {
    id: root
    property real s: 1
    required property var weatherData
    required property string configuredCity
    signal citySubmitted(string city)
    implicitHeight: wxCol.implicitHeight
    clip: true
    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    Column {
        id: wxCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6 * root.s
        spacing: 9 * root.s

        Row {
            visible: root.weatherData.ready
            spacing: 9 * root.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 32 * root.s
                height: 32 * root.s
                name: root.weatherData.glyphFor(root.weatherData.codeNow, root.weatherData.isDay)
                color: Theme.todayWarm
                stroke: 1.9
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    textFormat: Text.PlainText
                    text: root.weatherData.tempNow + "°"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 26 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    textFormat: Text.PlainText
                    text: root.weatherData.labelFor(root.weatherData.codeNow)
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Medium
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.weatherData.ready
            text: root.weatherData.status
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
        }

        Row {
            width: parent.width
            spacing: 8 * root.s

            Item {
                id: cityBox
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - humidityRow.width - 8 * root.s
                height: 14 * root.s

                property bool editing: false

                Text {
                    textFormat: Text.PlainText
                    id: cityText
                    visible: !cityBox.editing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.configuredCity.length > 0 ? root.configuredCity : "set town"
                    color: cityArea.containsMouse ? Theme.subtle : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: cityArea
                    visible: !cityBox.editing
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: Glitch.hover(root)
                    onClicked: { Glitch.click(root);
                        cityField.text = root.configuredCity;
                        cityBox.editing = true;
                        cityField.forceActiveFocus();
                        cityField.selectAll();
                    }
                }
                TextField {
                    id: cityField
                    visible: cityBox.editing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    background: null
                    padding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                    placeholderText: "town"
                    placeholderTextColor: Theme.faint
                    selectByMouse: true
                    selectionColor: Theme.verm
                    onAccepted: {
                        root.citySubmitted(text.trim());
                        cityBox.editing = false;
                    }
                    Keys.onEscapePressed: cityBox.editing = false
                    onActiveFocusChanged: if (!activeFocus) cityBox.editing = false
                }
            }
            Row {
                id: humidityRow
                visible: root.weatherData.ready
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11 * root.s
                    height: 11 * root.s
                    name: "droplet"
                    color: Theme.faint
                    stroke: 1.6
                }
                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.weatherData.humidity + "%"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
        }

        Rectangle {
            width: wxCol.width
            height: 1
            color: Theme.hairSoft
        }

        Row {
            width: wxCol.width

            Repeater {
                model: root.weatherData.daily.slice(0, 4)

                Column {
                    id: dayCol
                    required property var modelData
                    width: wxCol.width / 4
                    spacing: 5 * root.s

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dayCol.modelData.day
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.5 * root.s
                    }
                    GlyphIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 15 * root.s
                        height: 15 * root.s
                        name: root.weatherData.glyphFor(dayCol.modelData.code, true)
                        color: Theme.subtle
                        stroke: 1.7
                    }
                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dayCol.modelData.temp + "°"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2 * root.s

                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9 * root.s
                            height: 9 * root.s
                            name: "droplet"
                            color: Theme.faint
                            stroke: 1.6
                        }
                        Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: dayCol.modelData.rh + "%"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8.5 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
