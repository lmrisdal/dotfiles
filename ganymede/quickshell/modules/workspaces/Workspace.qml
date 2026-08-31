import Quickshell
import QtQuick

Item {
    id: root

    signal popupStateRequested(bool open)

    required property var desktopService
    property bool popupOpen: false
    property var selectedDesktop: null
    property int leftEdgeHitInset: 0

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
                required property int index
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
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: index === 0 ? -root.leftEdgeHitInset : 0
                    anchors.topMargin: index === 0 && root.leftEdgeHitInset > 0 ? -8 : 0
                    anchors.bottomMargin: index === 0 && root.leftEdgeHitInset > 0 ? -8 : 0
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.selectedDesktop = desktopButton.modelData
                            root.popupStateRequested(true)
                        } else {
                            root.popupOpen = false
                            root.desktopService.switchTo(desktopButton.modelData.id)
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: desktopMenu
        visible: root.popupOpen
        implicitWidth: 220
        implicitHeight: 84
        color: "transparent"
        grabFocus: true

        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
            adjustment: PopupAdjustment.All
        }

        onVisibleChanged: {
            if (!visible)
                root.popupOpen = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            focus: true

            Keys.onEscapePressed: event => {
                root.popupOpen = false
                event.accepted = true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 35
                    radius: 4
                    color: addDesktopMouse.containsMouse ? "#313244" : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+  Add virtual desktop"
                        color: "#cdd6f4"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: addDesktopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.popupOpen = false
                            root.desktopService.addDesktop()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 35
                    radius: 4
                    enabled: root.desktopService.desktops.length > 1
                    color: enabled && removeDesktopMouse.containsMouse ? "#313244" : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectedDesktop ? "−  Remove Desktop " + (root.selectedDesktop.position + 1) : "−  Remove virtual desktop"
                        color: parent.enabled ? "#cdd6f4" : "#6c7086"
                        elide: Text.ElideRight
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: removeDesktopMouse
                        anchors.fill: parent
                        enabled: parent.enabled
                        hoverEnabled: true
                        onClicked: {
                            const desktopId = root.selectedDesktop.id
                            root.popupOpen = false
                            root.desktopService.removeDesktop(desktopId)
                        }
                    }
                }
            }
        }
    }
}
