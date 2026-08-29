import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland._ToplevelManagement
import Quickshell.Widgets
import QtQuick
import org.kde.notificationmanager as KDE

Scope {
    id: root

    property var toastNotifications: []
    property alias server: notificationServer
    readonly property bool doNotDisturb: notificationSettings.notificationsInhibitedByApplication
        || notificationSettings.notificationsInhibitedUntil > dndClock.date
        || (notificationSettings.inhibitNotificationsWhenFullscreen
            && ToplevelManager.activeToplevel !== null
            && ToplevelManager.activeToplevel.fullscreen)
        || (notificationSettings.inhibitNotificationsWhenScreensMirrored
            && notificationSettings.screensMirrored)

    function shouldShowToast(notification) {
        return !doNotDisturb
            || (notification.urgency === NotificationUrgency.Critical
                && notificationSettings.criticalPopupsInDoNotDisturbMode)
    }

    function showToast(notification) {
        const withoutPrevious = toastNotifications.filter(item => item.id !== notification.id)
        const updatedNotifications = [notification].concat(withoutPrevious)
        const removedNotifications = updatedNotifications.slice(3)
        toastNotifications = updatedNotifications.slice(0, 3)

        removedNotifications.forEach(item => {
            if (item.transient && item.tracked)
                item.expire()
        })
    }

    function removeToast(notificationId) {
        toastNotifications = toastNotifications.filter(item => item.id !== notificationId)
    }

    function clearToasts() {
        const notifications = toastNotifications.slice()
        toastNotifications = []
        notifications.forEach(notification => {
            if (notification.transient && notification.tracked)
                notification.expire()
        })
    }

    onDoNotDisturbChanged: {
        if (doNotDisturb)
            clearToasts()
    }

    KDE.Settings {
        id: notificationSettings
    }

    SystemClock {
        id: dndClock
        precision: SystemClock.Seconds
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: true
        persistenceSupported: true

        onNotification: notification => {
            const showToast = root.shouldShowToast(notification)
            notification.tracked = !notification.transient || showToast
            if (showToast)
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
                    id: toastDelegate

                    required property var modelData
                    readonly property int notificationId: modelData.id
                    width: toastColumn.width
                    height: toastContent.implicitHeight + 20
                    radius: 8
                    color: "#1e1e2e"
                    border.color: "#45475a"
                    border.width: 1

                    Timer {
                        readonly property int requestedInterval: toastDelegate.modelData.expireTimeout < 0
                            ? notificationSettings.popupTimeout
                            : toastDelegate.modelData.expireTimeout
                        running: requestedInterval > 0
                        interval: Math.max(3000, requestedInterval)
                        onTriggered: {
                            if (toastDelegate.modelData.transient)
                                toastDelegate.modelData.expire()
                            else
                                root.removeToast(toastDelegate.notificationId)
                        }
                    }

                    Connections {
                        target: toastDelegate.modelData

                        function onClosed() {
                            root.removeToast(toastDelegate.notificationId)
                        }
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
                            const notification = toastDelegate.modelData
                            const notificationId = toastDelegate.notificationId
                            notification.dismiss()
                            root.removeToast(notificationId)
                        }
                    }
                }
            }
        }
    }
}
