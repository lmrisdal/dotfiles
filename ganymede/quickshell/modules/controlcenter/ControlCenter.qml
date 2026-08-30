import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property var tray
    required property var notificationServer
    required property bool doNotDisturb
    property bool popupOpen: false
    property real drawerProgress: 0
    property var selectedPowerAction: null
    readonly property int drawerHeight: selectedPowerAction
        ? 190
        : Math.min(520, contentColumn.implicitHeight + 28)

    implicitWidth: 40
    implicitHeight: 40

    function historyNotifications() {
        return notificationServer.trackedNotifications.values
            .filter(notification => !notification.transient)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: height / 2
            color: controlCenterMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
        }

        IconImage {
            id: controlCenterIcon
            anchors.centerIn: parent
            width: 22
            height: 22
            source: Quickshell.iconPath("configure")
            visible: false
        }

        ColorOverlay {
            anchors.fill: controlCenterIcon
            source: controlCenterIcon
            color: "#cdd6f4"
        }

        MouseArea {
            id: controlCenterMouse
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
        }
    }

    function showDrawer() {
        closeAnimation.stop()
        drawer.visible = true
        openAnimation.restart()
    }

    function hideDrawer() {
        if (!drawer.visible)
            return

        openAnimation.stop()
        closeAnimation.restart()
    }

    Component.onCompleted: {
        if (popupOpen)
            showDrawer()
    }

    onPopupOpenChanged: {
        if (popupOpen)
            showDrawer()
        else
            hideDrawer()
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "drawerProgress"
        to: 1
        duration: 160
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnimation
        target: root
        property: "drawerProgress"
        to: 0
        duration: 120
        easing.type: Easing.InCubic
        onFinished: {
            if (!root.popupOpen)
                drawer.visible = false
        }
    }

    PopupWindow {
        id: drawer

        visible: false
        implicitWidth: 380
        implicitHeight: 520
        color: "transparent"
        grabFocus: true
        mask: Region { item: drawerSurface }

        anchor {
            item: root
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            adjustment: PopupAdjustment.FlipX | PopupAdjustment.ResizeX | PopupAdjustment.SlideY
        }

        onVisibleChanged: {
            if (!visible) {
                root.selectedPowerAction = null
                root.popupOpen = false
            }
        }

        Rectangle {
            id: drawerSurface
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width
            height: root.drawerHeight
            radius: 8
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            focus: true
            opacity: root.drawerProgress
            transform: Translate { y: -8 * (1 - root.drawerProgress) }
    
            Keys.onEscapePressed: event => {
                if (root.selectedPowerAction)
                    root.selectedPowerAction = null
                else
                    root.popupOpen = false
                event.accepted = true
            }
    
            Column {
                id: contentColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 14
                width: parent.width - 28
                spacing: 12
                visible: !root.selectedPowerAction
    
                Item {
                    width: parent.width
                    height: 18
    
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.doNotDisturb ? "Notifications · Do Not Disturb" : "Notifications"
                        color: root.doNotDisturb ? "#f9e2af" : "#a6adc8"
                        font.pixelSize: 12
                        font.bold: true
                    }
    
                    Text {
                        id: clearButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.historyNotifications().length > 0
                        text: "Clear all"
                        color: clearMouse.containsMouse ? "#cdd6f4" : "#89b4fa"
                        font.pixelSize: 12
    
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const notifications = root.historyNotifications()
                                notifications.forEach(notification => notification.dismiss())
                            }
                        }
                    }
                }
    
                Item {
                    width: parent.width
                    height: Math.max(52, Math.min(notificationList.contentHeight, 220))
                    ListView {
                        id: notificationList
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: ScriptModel {
                            values: root.historyNotifications().slice().reverse()
                            objectProp: "id"
                            comparisonMode: ObjectComparison.Identity
                        }
    
                        delegate: Rectangle {
                            id: notificationDelegate

                            required property var modelData
                            property bool expanded: false
                            width: notificationList.width
                            height: notificationContent.implicitHeight + 18
                            radius: 6
                            color: "#313244"
    
                            Column {
                                id: notificationContent
                                anchors.left: parent.left
                                anchors.right: dismissButton.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
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
                                    id: notificationBody

                                    width: parent.width
                                    visible: text.length > 0
                                    text: modelData.body
                                    color: "#a6adc8"
                                    elide: notificationDelegate.expanded ? Text.ElideNone : Text.ElideRight
                                    maximumLineCount: notificationDelegate.expanded ? 100000 : 2
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                    font.pixelSize: 12
                                }

                                Text {
                                    id: expandButton

                                    visible: notificationDelegate.expanded || notificationBody.truncated
                                    text: notificationDelegate.expanded ? "Show less" : "Show more"
                                    color: expandMouse.containsMouse ? "#cdd6f4" : "#89b4fa"
                                    font.pixelSize: 11

                                    MouseArea {
                                        id: expandMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notificationDelegate.expanded = !notificationDelegate.expanded
                                    }
                                }
                            }
    
                            Text {
                                id: dismissButton
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                color: dismissMouse.containsMouse ? "#cdd6f4" : "#a6adc8"
                                font.pixelSize: 18
    
                                MouseArea {
                                    id: dismissMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: modelData.dismiss()
                                }
                            }
                        }
                    }
    
                    Text {
                        anchors.fill: parent
                        visible: root.historyNotifications().length === 0
                        text: "No notifications"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "#6c7086"
                        font.pixelSize: 13
                    }
                }
    
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#45475a"
                }
    
                Text {
                    text: "Hidden tray icons"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }
    
                Item {
                    width: parent.width
                    height: Math.max(32, iconGrid.implicitHeight)
    
                    Flow {
                        id: iconGrid
                        width: parent.width - showOnBarTarget.width - 12
                        spacing: 10
    
                        Repeater {
                            model: ScriptModel {
                                values: root.tray.orderedItems(true)
                                objectProp: "id"
                                comparisonMode: ObjectComparison.Identity
                            }
    
                            delegate: MouseArea {
                                id: controlCenterTrayIcon
                                required property var modelData
                                property bool didDrag: false
                                property real pressX: 0
                                property real pressY: 0
    
                                visible: root.tray.isHidden(modelData)
                                width: 22
                                height: 22
                                hoverEnabled: true
                                preventStealing: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    
                                IconImage {
                                    anchors.fill: parent
                                    source: modelData.icon
                                    opacity: controlCenterTrayIcon.didDrag ? 0.45 : 1
                                }
    
                                onPressed: mouse => {
                                    pressX = mouse.x
                                    pressY = mouse.y
                                    didDrag = false
                                }
    
                                onPositionChanged: mouse => {
                                    if (!pressed || !(pressedButtons & Qt.LeftButton))
                                        return
    
                                    const deltaX = mouse.x - pressX
                                    const deltaY = mouse.y - pressY
                                    if (Math.abs(deltaX) < 5 || Math.abs(deltaX) <= Math.abs(deltaY))
                                        return
    
                                    didDrag = true
                                    root.tray.reorderAt(controlCenterTrayIcon, controlCenterTrayIcon.parent,
                                                        controlCenterTrayIcon.x + mouse.x)
                                }
    
                                onReleased: mouse => {
                                    if (didDrag && root.tray.pointerIsOver(controlCenterTrayIcon, mouse.x, mouse.y,
                                                                          showOnBarTarget))
                                        root.tray.setManuallyHidden(modelData.id, false)
    
                                    Qt.callLater(() => didDrag = false)
                                }
    
                                function openMenu() {
                                    const position = mapToItem(null, 0, height)
                                    modelData.display(QsWindow.window, position.x, position.y)
                                }
    
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (didDrag)
                                            return
    
                                        if (modelData.onlyMenu)
                                            openMenu()
                                        else
                                            modelData.activate()
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate()
                                    } else if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                        openMenu()
                                    }
                                }
                            }
                        }
                    }
    
                    Rectangle {
                        id: showOnBarTarget
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 28
                        radius: 4
                        color: showOnBarMouse.containsMouse ? "#45475a" : "#313244"
    
                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: "#cdd6f4"
                            font.pixelSize: 20
                        }
    
                        MouseArea {
                            id: showOnBarMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.tray.hasHiddenItems
                        text: "No hidden tray icons"
                        color: "#6c7086"
                        font.pixelSize: 13
                    }
                }
    
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#45475a"
                }
    
                Text {
                    text: "Power"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }
    
                Row {
                    width: parent.width
                    spacing: 8
    
                    Repeater {
                        model: [
                            { label: "Sleep", icon: "⏾", command: ["systemctl", "suspend"] },
                            { label: "Log out", icon: "⇥", command: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"] },
                            { label: "Restart", icon: "↻", command: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndReboot"] },
                            { label: "Shut down", icon: "⏻", command: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndShutdown"] }
                        ]
    
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - parent.spacing * 3) / 4
                            height: 54
                            radius: 6
                            color: powerMouse.containsMouse ? "#45475a" : "#313244"
    
                            Column {
                                anchors.centerIn: parent
                                spacing: 1
    
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    color: "#cdd6f4"
                                    font.pixelSize: 20
                                }
    
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: "#cdd6f4"
                                    font.pixelSize: 11
                                }
                            }
    
                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.selectedPowerAction = modelData
                            }
                        }
                    }
                }
            }
    
            Column {
                anchors.centerIn: parent
                width: parent.width - 28
                visible: !!root.selectedPowerAction
                spacing: 14
    
                Text {
                    width: parent.width
                    text: root.selectedPowerAction ? root.selectedPowerAction.icon : ""
                    color: "#f38ba8"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 30
                }
    
                Text {
                    width: parent.width
                    text: root.selectedPowerAction ? root.selectedPowerAction.label + "?" : ""
                    color: "#cdd6f4"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 17
                    font.bold: true
                }
    
                Text {
                    width: parent.width
                    text: root.selectedPowerAction && root.selectedPowerAction.label === "Sleep"
                        ? "Your session will remain open."
                        : "Any unsaved work may be lost."
                    color: "#a6adc8"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                }
    
                Row {
                    width: parent.width
                    spacing: 8
    
                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: 36
                        radius: 6
                        color: cancelMouse.containsMouse ? "#45475a" : "#313244"
    
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: "#cdd6f4"
                            font.pixelSize: 13
                        }
    
                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.selectedPowerAction = null
                        }
                    }
    
                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: 36
                        radius: 6
                        color: confirmMouse.containsMouse ? "#eba0ac" : "#f38ba8"
    
                        Text {
                            anchors.centerIn: parent
                            text: root.selectedPowerAction ? root.selectedPowerAction.label : "Confirm"
                            color: "#1e1e2e"
                            font.pixelSize: 13
                            font.bold: true
                        }
    
                        MouseArea {
                            id: confirmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Quickshell.execDetached(root.selectedPowerAction.command)
                                root.selectedPowerAction = null
                                root.popupOpen = false
                            }
                        }
                    }
                }
            }
    }
}
}
