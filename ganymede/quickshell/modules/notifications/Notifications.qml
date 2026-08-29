import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick

Scope {
    id: root

    property var toastNotifications: []
    property alias server: notificationServer

    function showToast(notification) {
        const withoutPrevious = toastNotifications.filter(item => item.id !== notification.id)
        toastNotifications = [notification].concat(withoutPrevious).slice(0, 3)
    }

    function removeToast(notificationId) {
        toastNotifications = toastNotifications.filter(item => item.id !== notificationId)
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = !notification.transient
            root.showToast(notification)
        }
    }

    PanelWindow {
        screen: Quickshell.screens[0]

        anchors {
            top: true
            right: true
        }

        implicitWidth: 380
        implicitHeight: toastColumn.implicitHeight + 24
        color: "transparent"
        visible: root.toastNotifications.length > 0

        Column {
            id: toastColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Repeater {
                model: ScriptModel {
                    values: root.toastNotifications
                    objectProp: "id"
                    comparisonMode: ObjectComparison.Identity
                }

                delegate: Rectangle {
                    required property var modelData
                    width: toastColumn.width
                    height: toastContent.implicitHeight + 20
                    radius: 8
                    color: "#1e1e2e"
                    border.color: "#45475a"
                    border.width: 1

                    Timer {
                        running: true
                        interval: modelData.expireTimeout > 0
                            ? Math.max(3000, modelData.expireTimeout * 1000)
                            : 5000
                        onTriggered: root.removeToast(modelData.id)
                    }

                    Column {
                        id: toastContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        spacing: 3

                        Text {
                            width: parent.width
                            text: modelData.summary || modelData.appName
                            color: "#cdd6f4"
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: modelData.body
                            color: "#a6adc8"
                            elide: Text.ElideRight
                            maximumLineCount: 3
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.removeToast(modelData.id)
                            modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
