import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    signal clicked(var mouse)
    signal wheeled(var wheel)

    property url iconSource
    property color iconColor: "#cdd6f4"
    property real iconOpacity: 1
    property bool popupOpen: false
    property bool interactionEnabled: true
    property int acceptedButtons: Qt.LeftButton
    property int leftEdgeHitInset: 0
    property int rightEdgeHitInset: 0

    implicitWidth: 30
    implicitHeight: 40

    Rectangle {
        anchors.centerIn: parent
        width: 28
        height: 24
        radius: height / 2
        color: buttonMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
    }

    IconImage {
        id: sourceIcon
        anchors.centerIn: parent
        width: 22
        height: 22
        source: root.iconSource
        visible: false
    }

    ColorOverlay {
        anchors.fill: sourceIcon
        source: sourceIcon
        color: root.iconColor
        opacity: root.iconOpacity
    }

    MouseArea {
        id: buttonMouse

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: -root.leftEdgeHitInset
        anchors.rightMargin: -root.rightEdgeHitInset
        enabled: root.interactionEnabled
        acceptedButtons: root.acceptedButtons
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheeled(wheel)
    }
}
