import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property var shellScreen
    property var hiddenItemIds: []
    property var manuallyHiddenIds: []
    property var itemOrder: []
    property bool dragActive: false
    property var dragItem: null
    property bool dragSourceHidden: false
    property Item dragContainer: null
    property Item dragShowTarget: null
    property var dragInitialOrder: []
    property var dragInitialHiddenIds: []
    property real dragGlobalX: 0
    property real dragGlobalY: 0
    property real dragIconOffsetX: 0
    property real dragIconOffsetY: 0
    property bool dragOverBar: false
    property bool dragOverHiddenContainer: false
    property bool dragOverShowTarget: false
    property bool dragPreviewOnBar: false
    property bool dragRemoveCandidate: false
    readonly property real dragThreshold: Qt.styleHints.startDragDistance
    readonly property bool hasHiddenItems: SystemTray.items.values.some(item => isHidden(item))
    readonly property bool draggedItemCanShow: dragItem
        && manuallyHiddenIds.includes(dragItem.id)
        && dragItem.status !== Status.Passive
        && !hiddenItemIds.includes(dragItem.id)

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

    function arraysEqual(left, right) {
        return left.length === right.length && left.every((value, index) => value === right[index])
    }

    function orderIndex(item) {
        const index = itemOrder.indexOf(item.id)
        return index === -1 ? SystemTray.items.values.length + SystemTray.items.values.indexOf(item) : index
    }

    function orderedItems(hidden) {
        return SystemTray.items.values
            .filter(item => isHidden(item) === hidden
                    || (!hidden && dragPreviewOnBar && dragItem === item))
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
        const updatedOrder = order.map(item => item.id)
        if (!arraysEqual(itemOrder, updatedOrder))
            itemOrder = updatedOrder
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
        const updatedOrder = order.map(item => item.id)
        if (!arraysEqual(itemOrder, updatedOrder))
            itemOrder = updatedOrder
    }

    function globalRect(item) {
        if (!item)
            return null

        const position = item.mapToGlobal(0, 0)
        return {
            x: position.x,
            y: position.y,
            width: item.width,
            height: item.height
        }
    }

    function pointInRect(pointerX, pointerY, rect) {
        return rect
            && pointerX >= rect.x
            && pointerX <= rect.x + rect.width
            && pointerY >= rect.y
            && pointerY <= rect.y + rect.height
    }

    function reorderAtGlobal(sourceId, container, pointerX, pointerY, flowLayout) {
        const targets = container.children
            .filter(child => child.trayItem && child.trayItem.id !== sourceId && child.visible)
            .map(child => ({ child: child, rect: globalRect(child) }))
            .sort((left, right) => {
                if (flowLayout && Math.abs(left.rect.y - right.rect.y) > 2)
                    return left.rect.y - right.rect.y
                return left.rect.x - right.rect.x
            })

        if (targets.length === 0)
            return

        if (!flowLayout) {
            for (const target of targets) {
                if (pointerX < target.rect.x + target.rect.width / 2) {
                    reorder(sourceId, target.child.trayItem.id)
                    return
                }
            }

            reorderAfter(sourceId, targets[targets.length - 1].child.trayItem.id)
            return
        }

        const rows = []
        for (const target of targets) {
            let row = rows.find(candidate => Math.abs(candidate.y - target.rect.y) <= 2)
            if (!row) {
                row = { y: target.rect.y, targets: [] }
                rows.push(row)
            }
            row.targets.push(target)
        }

        let selectedRow = rows[rows.length - 1]
        for (let index = 0; index < rows.length; index++) {
            const nextRow = rows[index + 1]
            if (!nextRow || pointerY < (rows[index].y + nextRow.y) / 2) {
                selectedRow = rows[index]
                break
            }
        }

        for (const target of selectedRow.targets) {
            if (pointerX < target.rect.x + target.rect.width / 2) {
                reorder(sourceId, target.child.trayItem.id)
                return
            }
        }

        reorderAfter(sourceId, selectedRow.targets[selectedRow.targets.length - 1].child.trayItem.id)
    }

    function beginDrag(item, source, pointerX, pointerY, pressX, pressY,
                       hidden, container, showTarget) {
        if (dragActive)
            cancelDrag()

        dragActive = true
        dragItem = item
        dragSourceHidden = hidden
        dragContainer = container
        dragShowTarget = showTarget
        dragInitialOrder = itemOrder.slice()
        dragInitialHiddenIds = manuallyHiddenIds.slice()
        dragIconOffsetX = pressX - (source.width - 22) / 2
        dragIconOffsetY = pressY - (source.height - 22) / 2
        updateDrag(source, pointerX, pointerY)
    }

    function updateDrag(source, pointerX, pointerY) {
        if (!dragActive)
            return

        const pointer = source.mapToGlobal(pointerX, pointerY)
        dragGlobalX = pointer.x
        dragGlobalY = pointer.y

        const barRect = globalRect(layout)
        dragOverBar = pointInRect(pointer.x, pointer.y, barRect)
        dragOverHiddenContainer = dragSourceHidden
            && pointInRect(pointer.x, pointer.y, globalRect(dragContainer))
        dragOverShowTarget = dragSourceHidden
            && pointInRect(pointer.x, pointer.y, globalRect(dragShowTarget))
        dragPreviewOnBar = dragSourceHidden && draggedItemCanShow && dragOverBar
        dragRemoveCandidate = !dragSourceHidden && barRect && pointer.y > barRect.y + barRect.height

        if (dragOverBar && (!dragSourceHidden || draggedItemCanShow))
            reorderAtGlobal(dragItem.id, layout, pointer.x, pointer.y, false)
        else if (dragOverHiddenContainer)
            reorderAtGlobal(dragItem.id, dragContainer, pointer.x, pointer.y, true)
    }

    function resetDrag() {
        dragActive = false
        dragItem = null
        dragSourceHidden = false
        dragContainer = null
        dragShowTarget = null
        dragInitialOrder = []
        dragInitialHiddenIds = []
        dragOverBar = false
        dragOverHiddenContainer = false
        dragOverShowTarget = false
        dragPreviewOnBar = false
        dragRemoveCandidate = false
    }

    function cancelDrag() {
        if (!dragActive)
            return

        itemOrder = dragInitialOrder.slice()
        manuallyHiddenIds = dragInitialHiddenIds.slice()
        resetDrag()
    }

    function finishDrag() {
        if (!dragActive)
            return false

        let validDrop = false
        if (!dragSourceHidden && dragRemoveCandidate) {
            const updatedIds = manuallyHiddenIds.filter(id => id !== dragItem.id)
            updatedIds.push(dragItem.id)
            manuallyHiddenIds = updatedIds
            validDrop = true
        } else if (!dragSourceHidden && dragOverBar) {
            validDrop = true
        } else if (dragSourceHidden && draggedItemCanShow
                   && (dragPreviewOnBar || dragOverShowTarget)) {
            manuallyHiddenIds = manuallyHiddenIds.filter(id => id !== dragItem.id)
            validDrop = true
        } else if (dragSourceHidden && dragOverHiddenContainer) {
            validDrop = true
        }

        if (!validDrop) {
            cancelDrag()
            return false
        }

        saveState()
        resetDrag()
        return true
    }

    component TrayIcon: MouseArea {
        id: trayIcon
        required property var trayItem
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
            color: trayIcon.pressed && !(root.dragActive && root.dragItem === trayItem)
                ? "#585b70" : "transparent"
        }

        IconImage {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: trayItem.icon
            opacity: root.dragActive && root.dragItem === trayItem ? 0 : 1
        }

        Behavior on x {
            enabled: root.dragActive
            NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
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

            if (!didDrag && !(mouse.modifiers & Qt.ControlModifier))
                return

            const deltaX = mouse.x - pressX
            const deltaY = mouse.y - pressY

            if (!didDrag && Math.hypot(deltaX, deltaY) < root.dragThreshold)
                return

            if (!didDrag) {
                didDrag = true
                root.beginDrag(trayItem, trayIcon, mouse.x, mouse.y, pressX, pressY,
                               false, trayIcon.parent, null)
            } else {
                root.updateDrag(trayIcon, mouse.x, mouse.y)
            }
        }

        onReleased: mouse => {
            if (didDrag)
                root.finishDrag()

            Qt.callLater(() => didDrag = false)
        }

        onCanceled: {
            if (didDrag)
                root.cancelDrag()
            didDrag = false
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
                    || (root.dragPreviewOnBar && root.dragItem === modelData)
                trayItem: modelData
            }
        }
    }

    TrayDragOverlay {
        shellScreen: root.shellScreen
        dragActive: root.dragActive
        iconSource: root.dragItem ? root.dragItem.icon : ""
        iconX: root.dragGlobalX - root.shellScreen.x - root.dragIconOffsetX
        iconY: root.dragGlobalY - root.shellScreen.y - root.dragIconOffsetY
        removeCandidate: root.dragRemoveCandidate
    }
}
