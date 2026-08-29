import Quickshell
import QtQuick
import "../audio"
import "../calendar"
import "../budslink"
import "../network"
import "../notifications"
import "../tray"
import "../workspaces"

Scope {
    id: root

    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(clock.date, "dd.MM.yyyy")

    WorkspaceService {
        id: workspaces
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Notifications {
        id: notifications
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 40
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        calendar.open = false
                        budsLink.popupOpen = false
                        volume.popupOpen = false
                        tray.controlCenterOpen = false
                    }
                }

                Row {
                    id: leftControls
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    spacing: 8

                    Workspace {
                        height: leftControls.height
                        desktopService: workspaces
                    }
                }

                Rectangle {
                    id: clockButton
                    anchors.centerIn: parent
                    width: clockContent.implicitWidth + 16
                    height: parent.height
                    radius: 4
                    color: clockMouse.containsMouse ? "#313244" : "transparent"

                    Column {
                        id: clockContent
                        anchors.centerIn: parent
                        spacing: -3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.time
                            color: "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.date
                            color: "#a6adc8"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: calendar.open = !calendar.open
                    }
                }

                Calendar {
                    id: calendar
                    anchorItem: clockButton
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    BudsLink {
                        id: budsLink
                    }

                    Volume {
                        id: volume
                    }

                    Network { }

                    Tray {
                        id: tray
                        panelWindow: panel
                        notificationServer: notifications.server
                        // Add tray IDs here to move active applications into
                        // the overflow drawer, for example: ["steam", "discord"].
                        hiddenItemIds: [
                        ]
                    }
                }
            }
        }
    }
}
