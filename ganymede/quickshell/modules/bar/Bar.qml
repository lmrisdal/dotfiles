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
    property var activePopupOwner: null

    function updatePopupOwner(owner, isOpen) {
        if (isOpen) {
            if (activePopupOwner && activePopupOwner !== owner)
                activePopupOwner.popupOpen = false

            activePopupOwner = owner
        } else if (activePopupOwner === owner) {
            activePopupOwner = null
        }
    }

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
                        calendar.popupOpen = false
                        budsLink.popupOpen = false
                        volume.popupOpen = false
                        network.popupOpen = false
                        tray.popupOpen = false
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
                        onClicked: calendar.popupOpen = !calendar.popupOpen
                    }
                }

                Calendar {
                    id: calendar
                    anchorItem: clockButton
                    onPopupOpenChanged: root.updatePopupOwner(calendar, popupOpen)
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    BudsLink {
                        id: budsLink
                        onPopupOpenChanged: root.updatePopupOwner(budsLink, popupOpen)
                    }

                    Volume {
                        id: volume
                        onPopupOpenChanged: root.updatePopupOwner(volume, popupOpen)
                    }

                    Network {
                        id: network
                        onPopupOpenChanged: root.updatePopupOwner(network, popupOpen)
                    }

                    Tray {
                        id: tray
                        panelWindow: panel
                        notificationServer: notifications.server
                        doNotDisturb: notifications.doNotDisturb
                        onPopupOpenChanged: root.updatePopupOwner(tray, popupOpen)
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
