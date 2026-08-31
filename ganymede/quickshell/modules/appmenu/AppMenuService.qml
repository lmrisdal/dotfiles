pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml
import org.kde.taskmanager as TaskManager

Scope {
    id: root

    readonly property int protocolVersion: 1
    property bool bridgeAvailable: false
    property bool menuAvailable: false
    property var topLevelEntries: []
    property string viewerRegistration: "unavailable"
    property string applicationName: ""
    property string activeMenuService: ""
    property string activeMenuPath: ""
    property int openIndex: -1
    property string openScreen: ""
    property bool activeTaskSyncPending: false
    property bool menuRequestPending: false

    signal menuOpened(int index, string screenName)
    signal menuClosed(string screenName)

    function syncActiveTask() {
        if (openIndex >= 0 || menuRequestPending) {
            activeTaskSyncPending = true
            return
        }

        activeTaskSyncPending = false
        const activeTask = tasksModel.activeTask
        applicationName = activeTask.valid
            ? tasksModel.data(activeTask, TaskManager.AbstractTasksModel.AppName) || ""
            : ""
        activeMenuService = activeTask.valid
            ? tasksModel.data(activeTask, TaskManager.AbstractTasksModel.ApplicationMenuServiceName) || ""
            : ""
        activeMenuPath = activeTask.valid
            ? tasksModel.data(activeTask, TaskManager.AbstractTasksModel.ApplicationMenuObjectPath) || ""
            : ""

        sendActiveTask()
    }

    function sendActiveTask() {
        if (!bridge.running)
            return

        bridge.write(`${JSON.stringify({
            command: "set-active",
            applicationName: applicationName,
            service: activeMenuService,
            path: activeMenuPath
        })}\n`)
    }

    function openMenu(index, x, y, screenName) {
        if (!bridge.running || !menuAvailable)
            return

        const entry = topLevelEntries.find(candidate => candidate.index === index)
        menuRequestPending = entry?.hasMenu === true

        bridge.write(`${JSON.stringify({
            command: "open",
            index: index,
            x: Math.round(x),
            y: Math.round(y),
            screen: screenName
        })}\n`)
    }

    function closeMenu() {
        if (bridge.running)
            bridge.write(`${JSON.stringify({ command: "close" })}\n`)
    }

    function prepareAction(actionId) {
        if (!bridge.running)
            return

        bridge.write(`${JSON.stringify({
            command: "prepare-action",
            actionId: actionId
        })}\n`)
    }

    function triggerAction(actionId) {
        if (!bridge.running)
            return

        bridge.write(`${JSON.stringify({
            command: "trigger",
            actionId: actionId
        })}\n`)
    }

    function handleMessage(data) {
        try {
            const message = JSON.parse(data)
            if (message.protocol !== undefined && message.protocol !== protocolVersion) {
                console.warn(`Unsupported app-menu bridge protocol ${message.protocol}`)
                return
            }

            if (message.event === "ready") {
                menuAvailable = message.menuAvailable === true
                topLevelEntries = message.entries || []
                viewerRegistration = message.viewerRegistration || "failed"
                bridge.write(`${JSON.stringify({ command: "ping" })}\n`)
                sendActiveTask()
            } else if (message.event === "pong") {
                bridgeAvailable = true
            } else if (message.event === "state") {
                menuAvailable = message.menuAvailable === true
                topLevelEntries = message.entries || []
                if (!menuAvailable && openIndex >= 0) {
                    const closedScreen = openScreen
                    openIndex = -1
                    openScreen = ""
                    menuClosed(closedScreen)
                }
            } else if (message.event === "menu-opened") {
                menuRequestPending = false
                openIndex = message.index ?? -1
                openScreen = message.screen || ""
                menuOpened(openIndex, openScreen)
            } else if (message.event === "menu-closed") {
                menuRequestPending = false
                const closedScreen = openScreen || message.screen || ""
                openIndex = -1
                openScreen = ""
                menuClosed(closedScreen)
                if (activeTaskSyncPending)
                    Qt.callLater(syncActiveTask)
            } else if (message.event === "menu-open-failed") {
                menuRequestPending = false
                if (activeTaskSyncPending)
                    Qt.callLater(syncActiveTask)
            } else if (message.event === "registration") {
                viewerRegistration = message.viewerRegistration || "failed"
            } else if (message.event === "error") {
                console.warn("App-menu bridge error:", message.message)
            }
        } catch (error) {
            console.warn("Ignoring invalid app-menu bridge event:", error)
        }
    }

    Component.onCompleted: syncActiveTask()

    TaskManager.TasksModel {
        id: tasksModel

        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: false

        onActiveTaskChanged: root.syncActiveTask()
        onDataChanged: (topLeft, bottomRight, roles) => {
            if (roles.length === 0
                    || roles.includes(TaskManager.AbstractTasksModel.AppName)
                    || roles.includes(TaskManager.AbstractTasksModel.ApplicationMenuServiceName)
                    || roles.includes(TaskManager.AbstractTasksModel.ApplicationMenuObjectPath))
                root.syncActiveTask()
        }
        onActivityChanged: root.syncActiveTask()
        onVirtualDesktopChanged: root.syncActiveTask()
        onCountChanged: root.syncActiveTask()
        onScreenGeometryChanged: root.syncActiveTask()
    }

    Process {
        id: bridge

        command: [
            Quickshell.shellPath("build/appmenu-native/appmenu-helper"),
            "--protocol=1.1"
        ]
        running: true
        stdinEnabled: true

        onRunningChanged: {
            if (!running) {
                root.bridgeAvailable = false
                root.menuAvailable = false
                root.topLevelEntries = []
                root.viewerRegistration = "unavailable"
                const closedScreen = root.openScreen
                root.openIndex = -1
                root.openScreen = ""
                root.menuRequestPending = false
                if (closedScreen)
                    root.menuClosed(closedScreen)
            }
        }

        stdout: SplitParser {
            onRead: data => root.handleMessage(data)
        }
    }
}
