import Quickshell
import QtQuick

Item {
    id: root

    required property Item anchorItem
    property bool open: false
    property date displayedMonth: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)

    readonly property int firstDayOffset: (displayedMonth.getDay() + 6) % 7
    readonly property int daysInDisplayedMonth: new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + 1, 0).getDate()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function changeMonth(amount) {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + amount, 1)
    }

    function isToday(date) {
        const today = clock.date
        return date.getFullYear() === today.getFullYear()
            && date.getMonth() === today.getMonth()
            && date.getDate() === today.getDate()
    }

    function isoWeekNumber(date) {
        const utcDate = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
        const day = utcDate.getUTCDay() || 7
        utcDate.setUTCDate(utcDate.getUTCDate() + 4 - day)
        const yearStart = new Date(Date.UTC(utcDate.getUTCFullYear(), 0, 1))
        return Math.ceil(((utcDate - yearStart) / 86400000 + 1) / 7)
    }

    PopupWindow {
        id: popup
        visible: root.open
        implicitWidth: 330
        implicitHeight: 302
        color: "transparent"
        grabFocus: true

        anchor {
            item: root.anchorItem
            edges: Edges.Bottom
            gravity: Edges.Bottom
            adjustment: PopupAdjustment.All
        }

        onVisibleChanged: {
            if (!visible)
                root.open = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            focus: true

            Keys.onEscapePressed: event => {
                root.open = false
                event.accepted = true
            }

            Row {
                id: monthHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                height: 26

                Rectangle {
                    width: 26
                    height: 26
                    radius: 4
                    color: previousMonth.containsMouse ? "#313244" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: "#cdd6f4"
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: previousMonth
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.changeMonth(-1)
                    }
                }

                Text {
                    width: parent.width - 52
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.formatDate(root.displayedMonth, "MMMM yyyy")
                    color: "#cdd6f4"
                    font.bold: true
                    font.pixelSize: 14
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 4
                    color: nextMonth.containsMouse ? "#313244" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: "#cdd6f4"
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: nextMonth
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.changeMonth(1)
                    }
                }
            }

            Row {
                id: weekdayHeader
                anchors.top: monthHeader.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Text {
                    width: 26
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: "Wk"
                    color: "#6c7086"
                    font.pixelSize: 11
                    font.bold: true
                }

                Grid {
                    columns: 7
                    spacing: 2

                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                        Text {
                            required property string modelData
                            width: 36
                            height: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: "#a6adc8"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }

            Row {
                id: daysGrid
                anchors.top: weekdayHeader.bottom
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Column {
                    spacing: 2

                    Repeater {
                        model: 6

                        Text {
                            required property int index
                            readonly property date monday: new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth(), index * 7 - root.firstDayOffset + 1)

                            width: 26
                            height: 30
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.isoWeekNumber(monday)
                            color: "#6c7086"
                            font.pixelSize: 12
                        }
                    }
                }

                Grid {
                    columns: 7
                    spacing: 2

                    Repeater {
                        model: 42

                        Rectangle {
                            required property int index
                            readonly property date cellDate: new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth(), index - root.firstDayOffset + 1)
                            readonly property bool inDisplayedMonth: cellDate.getMonth() === root.displayedMonth.getMonth()

                            width: 36
                            height: 30
                            radius: 15
                            color: root.isToday(cellDate) ? "#89b4fa" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.cellDate.getDate()
                                color: parent.inDisplayedMonth ? (root.isToday(parent.cellDate) ? "#1e1e2e" : "#cdd6f4") : "#6c7086"
                                font.pixelSize: 13
                                font.bold: root.isToday(parent.cellDate)
                            }
                        }
                    }
                }
            }
        }
    }
}
