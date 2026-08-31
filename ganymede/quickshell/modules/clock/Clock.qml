import Quickshell
import QtQuick
import "../bar"
import "../calendar"

Item {
    id: root

    signal popupStateRequested(bool open)

    property alias popupOpen: calendar.popupOpen
    property int leftEdgeHitInset: 0
    property int rightEdgeHitInset: 0
    readonly property string time: Qt.formatDateTime(clock.date, "ddd dd MMM | HH:mm")

    implicitWidth: clockButton.implicitWidth
    implicitHeight: 40

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarTextButton {
        id: clockButton
        anchors.fill: parent
        text: root.time
        horizontalContentPadding: 8
        popupOpen: root.popupOpen
        leftEdgeHitInset: root.leftEdgeHitInset
        rightEdgeHitInset: root.rightEdgeHitInset
        onClicked: root.popupStateRequested(!root.popupOpen)
    }

    Calendar {
        id: calendar
        anchorItem: root
    }
}
