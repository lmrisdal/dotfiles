import Quickshell
import QtQuick
import "../appmenu"
import "../audio"
import "../calendar"
import "../budslink"
import "../controlcenter"
import "../media"
import "../network"
import "../notifications"
import "../tray"
import "../workspaces"

Scope {
    id: root

    readonly property string time: Qt.formatDateTime(clock.date, "ddd dd MMM | HH:mm")
    // readonly property string date: Qt.formatDateTime(clock.date, "dd.MM.yyyy")
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
                        mediaControls.popupOpen = false
                        controlCenter.popupOpen = false
                        workspace.popupOpen = false
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
                        id: workspace
                        height: leftControls.height
                        desktopService: workspaces
                        onPopupOpenChanged: root.updatePopupOwner(workspace, popupOpen)
                    }

                    AppMenu {
                        id: appMenu
                        height: leftControls.height
                    }
                }

                Calendar {
                    id: calendar
                    anchorItem: clockButton
                    onPopupOpenChanged: root.updatePopupOwner(calendar, popupOpen)
                }

                Rectangle {
                    id: clockButton
                    anchors.centerIn: parent
                    width: clockContent.implicitWidth + 24
                    height: parent.height
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: height / 2
                        color: clockMouse.pressed || calendar.popupOpen ? "#585b70" : "transparent"
                    }

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

                        // Text {
                        //     anchors.horizontalCenter: parent.horizontalCenter
                        //     text: root.date
                        //     color: "#a6adc8"
                        //     font.pixelSize: 12
                        //     font.bold: true
                        // }
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        onClicked: calendar.popupOpen = !calendar.popupOpen
                    }
                }

                Row {
                    id: rightControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    spacing: 0

                    BudsLink {
                        id: budsLink
                        anchors.verticalCenter: parent.verticalCenter
                        onPopupOpenChanged: root.updatePopupOwner(budsLink, popupOpen)
                    }

                    MediaControls {
                        id: mediaControls
                        height: parent.height
                        onPopupOpenChanged: root.updatePopupOwner(mediaControls, popupOpen)
                    }

                    Tray {
                        id: tray
                        height: parent.height
                        overflowTarget: controlCenter
                        // Add tray IDs here to move active applications into
                        // the overflow drawer, for example: ["steam", "discord"].
                        hiddenItemIds: [
                        ]
                    }

                    Volume {
                        id: volume
                        anchors.verticalCenter: parent.verticalCenter
                        onPopupOpenChanged: root.updatePopupOwner(volume, popupOpen)
                    }

                    Network {
                        id: network
                        anchors.verticalCenter: parent.verticalCenter
                        onPopupOpenChanged: root.updatePopupOwner(network, popupOpen)
                    }

                    ControlCenter {
                        id: controlCenter
                        height: parent.height
                        tray: tray
                        notificationServer: notifications.server
                        doNotDisturb: notifications.doNotDisturb
                        onPopupOpenChanged: root.updatePopupOwner(controlCenter, popupOpen)
                    }
                }
            }
        }
    }
}
