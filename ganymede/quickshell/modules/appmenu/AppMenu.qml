import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property var screen
    property real maximumWidth: 720
    property bool popupOpen: false
    property int selectedIndex: -1
    property var selectedButton: null
    property var submenuPath: []
    property var menuLevels: []
    property int keyboardLevel: 0
    property var keyboardActionIds: []
    property bool applyingBridgeState: false
    readonly property string applicationName: AppMenuService.applicationName
    readonly property string screenName: screen ? screen.name : ""
    readonly property int menuColumnWidth: 240
    readonly property int popupContentHeight: calculatePopupHeight()

    visible: applicationName !== ""
    clip: true
    implicitWidth: visible ? Math.min(contentRow.implicitWidth, maximumWidth) : 0
    implicitHeight: 40

    onPopupOpenChanged: {
        if (!applyingBridgeState && !popupOpen && AppMenuService.openScreen === screenName)
            AppMenuService.closeMenu()
    }

    function topEntry(index) {
        return AppMenuService.topLevelEntries.find(entry => entry.index === index) || null
    }

    function buttonForIndex(index) {
        for (let position = 0; position < menuRepeater.count; ++position) {
            const button = menuRepeater.itemAt(position)
            if (button && button.entryIndex === index)
                return button
        }
        return null
    }

    function rebuildMenuLevels() {
        const selectedEntry = topEntry(selectedIndex)
        if (!selectedEntry || !selectedEntry.hasMenu) {
            menuLevels = []
            submenuPath = []
            return
        }

        let actions = selectedEntry.children || []
        const levels = [actions]
        const validPath = []
        for (const actionId of submenuPath) {
            const action = actions.find(candidate => candidate.actionId === actionId)
            if (!action || !action.hasMenu)
                break

            validPath.push(actionId)
            actions = action.children || []
            levels.push(actions)
        }

        submenuPath = validPath
        menuLevels = levels
        keyboardLevel = Math.min(keyboardLevel, Math.max(0, levels.length - 1))
        ensureKeyboardSelection(keyboardLevel)
    }

    function calculatePopupHeight() {
        let maximum = 0
        for (const actions of menuLevels) {
            let height = 16
            for (const action of actions) {
                if (!action.visible)
                    continue
                height += action.separator ? 9 : 30
            }
            maximum = Math.max(maximum, height)
        }
        return Math.min(maximum, Math.max(120, (screen?.height || 720) - 64))
    }

    function selectableActions(level) {
        if (level < 0 || level >= menuLevels.length)
            return []
        return menuLevels[level].filter(action => action.visible && !action.separator && action.enabled)
    }

    function ensureKeyboardSelection(level) {
        const actions = selectableActions(level)
        if (actions.length === 0)
            return

        const updated = keyboardActionIds.slice()
        if (!actions.some(action => action.actionId === updated[level]))
            updated[level] = actions[0].actionId
        keyboardActionIds = updated
    }

    function keyboardAction() {
        const actions = selectableActions(keyboardLevel)
        const actionId = keyboardActionIds[keyboardLevel]
        return actions.find(action => action.actionId === actionId) || actions[0] || null
    }

    function moveKeyboardSelection(offset) {
        const actions = selectableActions(keyboardLevel)
        if (actions.length === 0)
            return

        const currentId = keyboardActionIds[keyboardLevel]
        let position = actions.findIndex(action => action.actionId === currentId)
        if (position < 0)
            position = 0
        position = (position + offset + actions.length) % actions.length

        const updated = keyboardActionIds.slice()
        updated[keyboardLevel] = actions[position].actionId
        keyboardActionIds = updated
    }

    function openSubmenu(level, action) {
        const updatedPath = submenuPath.slice(0, level)
        updatedPath.push(action.actionId)
        submenuPath = updatedPath
        AppMenuService.prepareAction(action.actionId)
        rebuildMenuLevels()
    }

    function hoverAction(level, action) {
        keyboardLevel = level
        const updated = keyboardActionIds.slice()
        updated[level] = action.actionId
        keyboardActionIds = updated

        if (action.hasMenu) {
            openSubmenu(level, action)
        } else if (submenuPath.length > level) {
            submenuPath = submenuPath.slice(0, level)
            rebuildMenuLevels()
        }
    }

    function activateAction(level, action) {
        if (!action || !action.enabled)
            return

        if (action.hasMenu) {
            openSubmenu(level, action)
            keyboardLevel = level + 1
            ensureKeyboardSelection(keyboardLevel)
        } else {
            AppMenuService.triggerAction(action.actionId)
            AppMenuService.closeMenu()
        }
    }

    function openTopEntry(entry) {
        const button = buttonForIndex(entry.index)
        if (!button)
            return

        selectedButton = button
        const position = button.mapToGlobal(0, button.height)
        AppMenuService.openMenu(entry.index, position.x, position.y, screenName)
    }

    function switchTopEntry(offset) {
        const entries = AppMenuService.topLevelEntries.filter(entry =>
            entry.visible && !entry.separator && entry.enabled && entry.hasMenu)
        if (entries.length === 0)
            return

        let position = entries.findIndex(entry => entry.index === selectedIndex)
        if (position < 0)
            position = 0
        position = (position + offset + entries.length) % entries.length
        openTopEntry(entries[position])
    }

    function applyOpenState(index, openScreen) {
        applyingBridgeState = true
        selectedIndex = openScreen === screenName ? index : -1
        popupOpen = openScreen === screenName && index >= 0
        if (popupOpen) {
            selectedButton = buttonForIndex(index)
            submenuPath = []
            keyboardLevel = 0
            keyboardActionIds = []
            rebuildMenuLevels()
        } else {
            selectedButton = null
            submenuPath = []
            menuLevels = []
        }
        applyingBridgeState = false
    }

    Connections {
        target: AppMenuService

        function onTopLevelEntriesChanged() {
            if (!root.popupOpen)
                return

            root.rebuildMenuLevels()
            Qt.callLater(() => root.selectedButton = root.buttonForIndex(root.selectedIndex))
        }

        function onMenuOpened(index, screenName) {
            root.applyOpenState(index, screenName)
        }

        function onMenuClosed(screenName) {
            if (!screenName || screenName === root.screenName)
                root.applyOpenState(-1, "")
        }
    }

    Row {
        id: contentRow

        height: parent.height
        spacing: 0

        Item {
            width: Math.min(applicationLabel.implicitWidth + 16, 256)
            height: parent.height

            Text {
                id: applicationLabel

                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.applicationName
                color: "#cdd6f4"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Repeater {
            id: menuRepeater

            model: AppMenuService.menuAvailable ? AppMenuService.topLevelEntries : []

            delegate: Item {
                id: menuEntry

                required property var modelData
                readonly property int entryIndex: modelData.index
                readonly property bool entryVisible: modelData.visible && !modelData.separator

                visible: entryVisible
                width: visible ? Math.max(menuLabel.implicitWidth + 16, 36) : 0
                height: contentRow.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: height / 2
                    color: root.selectedIndex === menuEntry.entryIndex || menuMouse.pressed
                        ? "#585b70"
                        : menuMouse.containsMouse ? "#313244" : "transparent"
                }

                Text {
                    id: menuLabel

                    anchors.centerIn: parent
                    text: menuEntry.modelData.text
                    color: menuEntry.modelData.enabled ? "#cdd6f4" : "#6c7086"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: menuMouse

                    anchors.fill: parent
                    enabled: menuEntry.modelData.enabled
                    hoverEnabled: true

                    onPressed: mouse => {
                        root.openTopEntry(menuEntry.modelData)
                        mouse.accepted = true
                    }

                    onEntered: {
                        if (AppMenuService.openIndex >= 0 && AppMenuService.openScreen === root.screenName)
                            root.openTopEntry(menuEntry.modelData)
                    }
                }
            }
        }
    }

    PopupWindow {
        id: menuPopup

        visible: root.popupOpen && root.menuLevels.length > 0 && root.selectedButton !== null
        implicitWidth: Math.min(
            root.menuLevels.length * root.menuColumnWidth + 2,
            Math.max(root.menuColumnWidth + 2, (root.screen?.width || 1280) - 24)
        )
        implicitHeight: root.popupContentHeight + 2
        color: "transparent"
        grabFocus: true

        anchor {
            item: root
            rect.x: root.selectedButton ? root.selectedButton.x : 0
            edges: Edges.Bottom | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            adjustment: PopupAdjustment.All
        }

        onVisibleChanged: {
            if (!visible && root.popupOpen)
                AppMenuService.closeMenu()
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            focus: true
            clip: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    AppMenuService.closeMenu()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    root.moveKeyboardSelection(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.moveKeyboardSelection(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    const action = root.keyboardAction()
                    if (action?.hasMenu)
                        root.activateAction(root.keyboardLevel, action)
                    else
                        root.switchTopEntry(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Left) {
                    if (root.keyboardLevel > 0) {
                        root.submenuPath = root.submenuPath.slice(0, -1)
                        root.keyboardLevel -= 1
                        root.rebuildMenuLevels()
                    } else {
                        root.switchTopEntry(-1)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.activateAction(root.keyboardLevel, root.keyboardAction())
                    event.accepted = true
                }
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                contentWidth: menuColumns.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: menuColumns

                    height: parent.height
                    spacing: 0

                    Repeater {
                        model: root.menuLevels

                        delegate: Rectangle {
                            id: menuColumn

                            required property int index
                            required property var modelData
                            readonly property int levelIndex: index
                            readonly property var levelActions: modelData

                            width: root.menuColumnWidth
                            height: menuColumns.height
                            color: "transparent"
                            border.color: levelIndex > 0 ? "#313244" : "transparent"
                            border.width: levelIndex > 0 ? 1 : 0

                            ListView {
                                anchors.fill: parent
                                anchors.margins: 8
                                model: menuColumn.levelActions
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Item {
                                    id: popupEntry

                                    required property int index
                                    required property var modelData
                                    readonly property var actionData: modelData

                                    visible: actionData.visible
                                    width: ListView.view.width
                                    height: !visible ? 0 : actionData.separator ? 9 : 30

                                    Rectangle {
                                        visible: popupEntry.actionData.separator
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 1
                                        color: "#45475a"
                                    }

                                    Rectangle {
                                        visible: !popupEntry.actionData.separator
                                        anchors.fill: parent
                                        radius: 5
                                        color: popupMouse.containsMouse
                                                || root.keyboardActionIds[menuColumn.levelIndex]
                                                    === popupEntry.actionData.actionId
                                            ? "#313244" : "transparent"
                                    }

                                    Text {
                                        visible: !popupEntry.actionData.separator && popupEntry.actionData.checkable
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        horizontalAlignment: Text.AlignHCenter
                                        text: popupEntry.actionData.radio
                                            ? popupEntry.actionData.checked ? "●" : "○"
                                            : popupEntry.actionData.checked ? "✓" : "□"
                                        color: popupEntry.actionData.enabled ? "#cdd6f4" : "#6c7086"
                                        font.pixelSize: 12
                                    }

                                    IconImage {
                                        visible: !popupEntry.actionData.separator
                                            && !popupEntry.actionData.checkable
                                            && (popupEntry.actionData.iconName || popupEntry.actionData.iconSource)
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        source: popupEntry.actionData.iconSource
                                            || Quickshell.iconPath(popupEntry.actionData.iconName)
                                    }

                                    Text {
                                        visible: !popupEntry.actionData.separator
                                        anchors.left: parent.left
                                        anchors.leftMargin: 28
                                        anchors.right: shortcutLabel.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: popupEntry.actionData.text
                                        color: popupEntry.actionData.enabled ? "#cdd6f4" : "#6c7086"
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: shortcutLabel

                                        visible: !popupEntry.actionData.separator
                                            && !popupEntry.actionData.hasMenu
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: popupEntry.actionData.shortcut
                                        color: "#6c7086"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        visible: !popupEntry.actionData.separator
                                            && popupEntry.actionData.hasMenu
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "›"
                                        color: popupEntry.actionData.enabled ? "#cdd6f4" : "#6c7086"
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        id: popupMouse

                                        anchors.fill: parent
                                        enabled: !popupEntry.actionData.separator
                                            && popupEntry.actionData.enabled
                                        hoverEnabled: true
                                        onEntered: root.hoverAction(
                                            menuColumn.levelIndex,
                                            popupEntry.actionData
                                        )
                                        onClicked: root.activateAction(
                                            menuColumn.levelIndex,
                                            popupEntry.actionData
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
