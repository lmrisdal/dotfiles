import QtQuick

Item {
    id: root

    signal clicked(var mouse)

    property string text: ""
    property color textColor: "#cdd6f4"
    property int fontPixelSize: 14
    property bool fontBold: true
    property int horizontalContentPadding: 8
    property bool popupOpen: false
    property int acceptedButtons: Qt.LeftButton
    property int leftEdgeHitInset: 0
    property int rightEdgeHitInset: 0

    implicitWidth: contentText.implicitWidth + horizontalContentPadding * 2
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: buttonMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
    }

    Text {
        id: contentText
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.pixelSize: root.fontPixelSize
        font.bold: root.fontBold
    }

    MouseArea {
        id: buttonMouse

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: -root.leftEdgeHitInset
        anchors.rightMargin: -root.rightEdgeHitInset
        acceptedButtons: root.acceptedButtons
        onClicked: mouse => root.clicked(mouse)
    }
}
