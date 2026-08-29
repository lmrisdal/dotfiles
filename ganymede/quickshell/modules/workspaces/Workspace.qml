import QtQuick

Item {
    id: root

    required property var desktopService

    implicitWidth: desktopLayout.implicitWidth
    implicitHeight: desktopLayout.implicitHeight
    visible: desktopService.desktops.length > 0

    Row {
        id: desktopLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.desktopService.desktops

            delegate: Rectangle {
                id: desktopButton
                required property var modelData

                readonly property bool active: modelData.id === root.desktopService.currentDesktopId

                width: active ? 30 : 14
                height: 24
                color: "transparent"

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: desktopButton.active ? 28 : 10
                    height: 10
                    radius: height / 2
                    color: desktopButton.active ? "#cdd6f4" : "transparent"
                    border.color: desktopMouse.containsMouse ? "#cdd6f4" : "#a6adc8"
                    border.width: desktopButton.active ? 0 : 1

                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                MouseArea {
                    id: desktopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.desktopService.switchTo(desktopButton.modelData.id)
                }
            }
        }
    }
}
