import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property var panelWindow
    required property var notificationServer
    required property bool doNotDisturb
    property var hiddenItemIds: []
    property var manuallyHiddenIds: []
    property var itemOrder: []
    readonly property bool hasHiddenItems: SystemTray.items.values.some(item => isHidden(item))
    property bool popupOpen: false
    property alias trailingControls: trailingControls

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    FileView {
        id: orderFile
        path: Quickshell.statePath("tray-order.json")
        blockLoading: true
        printErrors: false

        Component.onCompleted: {
            const savedOrder = text()
            if (!savedOrder)
                return

            try {
                const savedState = JSON.parse(savedOrder)
                root.itemOrder = Array.isArray(savedState) ? savedState : savedState.order || []
                root.manuallyHiddenIds = Array.isArray(savedState) ? [] : savedState.hiddenIds || []
            } catch (error) {
                console.warn("Ignoring invalid saved tray order:", error)
            }
        }
    }

    function isHidden(item) {
        return item.status === Status.Passive
            || hiddenItemIds.includes(item.id)
            || manuallyHiddenIds.includes(item.id)
    }

    function saveState() {
        orderFile.setText(JSON.stringify({
            order: itemOrder,
            hiddenIds: manuallyHiddenIds
        }))
    }

    function setManuallyHidden(itemId, hidden) {
        const updatedIds = manuallyHiddenIds.filter(id => id !== itemId)
        if (hidden)
            updatedIds.push(itemId)

        manuallyHiddenIds = updatedIds
        saveState()
    }

    function pointerIsOver(source, pointerX, pointerY, target) {
        const pointer = source.mapToItem(null, pointerX, pointerY)
        const targetPosition = target.mapToItem(null, 0, 0)
        return pointer.x >= targetPosition.x
            && pointer.x <= targetPosition.x + target.width
            && pointer.y >= targetPosition.y
            && pointer.y <= targetPosition.y + target.height
    }

    function orderIndex(item) {
        const index = itemOrder.indexOf(item.id)
        return index === -1 ? SystemTray.items.values.length + SystemTray.items.values.indexOf(item) : index
    }

    function orderedItems(hidden) {
        return SystemTray.items.values
            .filter(item => isHidden(item) === hidden)
            .sort((left, right) => orderIndex(left) - orderIndex(right))
    }

    function reorder(sourceId, targetId) {
        if (sourceId === targetId)
            return

        const order = SystemTray.items.values
            .slice()
            .sort((left, right) => orderIndex(left) - orderIndex(right))
        const sourceIndex = order.findIndex(item => item.id === sourceId)
        const targetIndex = order.findIndex(item => item.id === targetId)

        if (sourceIndex === -1 || targetIndex === -1)
            return

        const source = order.splice(sourceIndex, 1)[0]
        order.splice(order.findIndex(item => item.id === targetId), 0, source)
        itemOrder = order.map(item => item.id)
        saveState()
    }

    function reorderAfter(sourceId, targetId) {
        if (sourceId === targetId)
            return

        const order = SystemTray.items.values
            .slice()
            .sort((left, right) => orderIndex(left) - orderIndex(right))
        const sourceIndex = order.findIndex(item => item.id === sourceId)
        const targetIndex = order.findIndex(item => item.id === targetId)

        if (sourceIndex === -1 || targetIndex === -1)
            return

        const source = order.splice(sourceIndex, 1)[0]
        const insertAt = order.findIndex(item => item.id === targetId) + 1
        order.splice(insertAt, 0, source)
        itemOrder = order.map(item => item.id)
        saveState()
    }

    function reorderAt(source, container, pointerX) {
        const targets = container.children
            .filter(child => child !== source && child.trayItem && child.hidden === source.hidden)
            .sort((left, right) => left.x - right.x)

        if (targets.length === 0)
            return

        for (let index = 0; index < targets.length; index++) {
            const target = targets[index]
            if (pointerX < target.x + target.width / 2) {
                reorder(source.trayItem.id, target.trayItem.id)
                return
            }
        }

        reorderAfter(source.trayItem.id, targets[targets.length - 1].trayItem.id)
    }

    component TrayIcon: MouseArea {
        id: trayIcon
        required property var trayItem
        property bool hidden: false
        property var showTarget: null
        property bool didDrag: false
        property real pressX: 0
        property real pressY: 0

        width: 30
        height: 40
        anchors.verticalCenter: parent.verticalCenter
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            radius: height / 2
            color: trayIcon.pressed ? "#585b70" : "transparent"
        }

        IconImage {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: trayItem.icon
            opacity: trayIcon.didDrag ? 0.45 : 1
        }

        preventStealing: true

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
            root.reorderAt(trayIcon, trayIcon.parent, trayIcon.x + mouse.x)
        }

        onReleased: mouse => {
            if (didDrag && !hidden && root.pointerIsOver(trayIcon, mouse.x, mouse.y, overflowButton))
                root.setManuallyHidden(trayItem.id, true)
            else if (didDrag && hidden && showTarget
                     && root.pointerIsOver(trayIcon, mouse.x, mouse.y, showTarget))
                root.setManuallyHidden(trayItem.id, false)

            Qt.callLater(() => didDrag = false)
        }

        function openMenu() {
            const position = mapToItem(null, 0, height)
            trayItem.display(QsWindow.window, position.x, position.y)
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (didDrag)
                    return

                if (trayItem.onlyMenu)
                    openMenu()
                else
                    trayItem.activate()
            } else if (mouse.button === Qt.MiddleButton) {
                trayItem.secondaryActivate()
            } else if (mouse.button === Qt.RightButton && trayItem.hasMenu) {
                openMenu()
            }
        }
    }

    Row {
        id: layout
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: ScriptModel {
                values: root.orderedItems(false)
                objectProp: "id"
                comparisonMode: ObjectComparison.Identity
            }

            delegate: TrayIcon {
                required property var modelData
                visible: !root.isHidden(modelData)
                hidden: false
                trayItem: modelData
            }
        }

        Row {
            id: trailingControls
            height: parent.height
            spacing: 0
        }

        Rectangle {
            id: overflowButton
            width: 40
            height: parent.height
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: height / 2
                color: overflowMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
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
                id: overflowMouse
                anchors.fill: parent
                onClicked: root.popupOpen = !root.popupOpen
            }
        }
    }

    ControlCenter {
        anchorItem: overflowButton
        tray: root
        notificationServer: root.notificationServer
        doNotDisturb: root.doNotDisturb
    }
}
