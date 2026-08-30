import Quickshell
import QtQuick
import "../calendar"

Item {
    id: root

    property alias popupOpen: calendar.popupOpen
    readonly property string time: Qt.formatDateTime(clock.date, "ddd dd MMM | HH:mm")

    implicitWidth: clockContent.implicitWidth + 24
    implicitHeight: 40

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: height / 2
            color: clockMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
        }

        Text {
            id: clockContent
            anchors.centerIn: parent
            text: root.time
            color: "#cdd6f4"
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            id: clockMouse
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
        }
    }

    Calendar {
        id: calendar
        anchorItem: root
    }
}
