import Quickshell
import Quickshell.Io
import QtQuick
import "../appmenu"
import "../audio"
import "../budslink"
import "../clock"
import "../controlcenter"
import "../media"
import "../network"
import "../notifications"
import "../tray"
import "../workspaces"

Scope {
    id: root

    readonly property var knownItems: [
        "workspace",
        "appmenu",
        "clock",
        "budslink",
        "media",
        "tray",
        "network",
        "audio",
        "control_center"
    ]
    readonly property var configuredLayout: normalizedLayout(
        layoutConfig.left,
        layoutConfig.middle,
        layoutConfig.right
    )
    property var activePopupOwner: null
    property var pendingPopupOwner: null

    function normalizedLayout(left, middle, right) {
        const result = { left: [], middle: [], right: [] }
        const seen = []

        for (const section of ["left", "middle", "right"]) {
            const configuredItems = section === "left" ? left : section === "middle" ? middle : right
            for (const itemName of configuredItems) {
                if (!knownItems.includes(itemName)) {
                    console.warn(`Ignoring unknown bar item: ${itemName}`)
                    continue
                }

                if (seen.includes(itemName)) {
                    console.warn(`Ignoring duplicate bar item: ${itemName}`)
                    continue
                }

                seen.push(itemName)
                result[section].push(itemName)
            }
        }

        return result
    }

    function updatePopupOwner(owner, isOpen) {
        if (isOpen) {
            if (activePopupOwner && activePopupOwner !== owner)
                activePopupOwner.popupOpen = false

            activePopupOwner = owner
        } else if (activePopupOwner === owner) {
            activePopupOwner = null
        }
    }

    function requestPopupState(owner, shouldOpen) {
        if (!shouldOpen) {
            if (pendingPopupOwner === owner) {
                pendingPopupOwner = null
                popupHandoffTimer.stop()
            }
            owner.popupOpen = false
            return
        }

        if (popupHandoffTimer.running) {
            pendingPopupOwner = owner
            return
        }

        if (!activePopupOwner || activePopupOwner === owner) {
            owner.popupOpen = true
            return
        }

        pendingPopupOwner = owner
        activePopupOwner.popupOpen = false
        popupHandoffTimer.restart()
    }

    function closeActivePopup() {
        pendingPopupOwner = null
        popupHandoffTimer.stop()
        if (activePopupOwner)
            activePopupOwner.popupOpen = false
    }

    Timer {
        id: popupHandoffTimer
        interval: 140
        onTriggered: {
            const owner = root.pendingPopupOwner
            root.pendingPopupOwner = null
            if (owner)
                owner.popupOpen = true
        }
    }

    FileView {
        path: Qt.resolvedUrl("../../bar.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: layoutConfig

            property int horizontalPadding: 12
            property int itemSpacing: 0
            property list<string> left: []
            property list<string> middle: []
            property list<string> right: []
        }
    }

    WorkspaceService {
        id: workspaces
    }

    Notifications {
        id: notifications
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            property var itemRegistry: ({})

            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 40
            color: "transparent"

            Rectangle {
                id: barSurface

                anchors.fill: parent
                color: "transparent"

                function componentFor(itemName) {
                    const components = {
                        workspace: workspaceComponent,
                        appmenu: appMenuComponent,
                        clock: clockComponent,
                        budslink: budsLinkComponent,
                        media: mediaComponent,
                        tray: trayComponent,
                        network: networkComponent,
                        audio: audioComponent,
                        control_center: controlCenterComponent
                    }
                    return components[itemName] || null
                }

                function registerItem(itemName, item) {
                    const updatedRegistry = Object.assign({}, panel.itemRegistry)
                    updatedRegistry[itemName] = item
                    panel.itemRegistry = updatedRegistry
                }

                function unregisterItem(itemName, item) {
                    if (panel.itemRegistry[itemName] !== item)
                        return

                    const updatedRegistry = Object.assign({}, panel.itemRegistry)
                    delete updatedRegistry[itemName]
                    panel.itemRegistry = updatedRegistry
                }

                function itemFor(itemName) {
                    return panel.itemRegistry[itemName] || null
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeActivePopup()
                }

                Item {
                    id: barContent

                    anchors.fill: parent
                    anchors.leftMargin: layoutConfig.horizontalPadding
                    anchors.rightMargin: layoutConfig.horizontalPadding

                    BarSection {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: layoutConfig.itemSpacing
                        itemNames: root.configuredLayout.left
                        barContext: barSurface
                    }

                    BarSection {
                        anchors.centerIn: parent
                        spacing: layoutConfig.itemSpacing
                        itemNames: root.configuredLayout.middle
                        barContext: barSurface
                    }

                    BarSection {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: layoutConfig.itemSpacing
                        itemNames: root.configuredLayout.right
                        barContext: barSurface
                    }
                }

                Component {
                    id: workspaceComponent

                    Workspace {
                        id: workspaceItem
                        leftEdgeHitInset: root.configuredLayout.left[0] === "workspace"
                            ? layoutConfig.horizontalPadding : 0
                        desktopService: workspaces
                        onPopupStateRequested: shouldOpen => root.requestPopupState(workspaceItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(workspaceItem, popupOpen)
                    }
                }

                Component {
                    id: appMenuComponent

                    AppMenu { }
                }

                Component {
                    id: clockComponent

                    Clock {
                        id: clockItem
                        leftEdgeHitInset: root.configuredLayout.left[0] === "clock"
                            ? layoutConfig.horizontalPadding : 0
                        rightEdgeHitInset: root.configuredLayout.right[root.configuredLayout.right.length - 1] === "clock"
                            ? layoutConfig.horizontalPadding : 0
                        onPopupStateRequested: shouldOpen => root.requestPopupState(clockItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(clockItem, popupOpen)
                    }
                }

                Component {
                    id: budsLinkComponent

                    BudsLink {
                        id: budsLinkItem
                        onPopupStateRequested: shouldOpen => root.requestPopupState(budsLinkItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(budsLinkItem, popupOpen)
                    }
                }

                Component {
                    id: mediaComponent

                    MediaControls {
                        id: mediaItem
                        onPopupStateRequested: shouldOpen => root.requestPopupState(mediaItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(mediaItem, popupOpen)
                    }
                }

                Component {
                    id: trayComponent

                    Tray {
                        shellScreen: panel.screen
                        hiddenItemIds: [
                        ]
                    }
                }

                Component {
                    id: networkComponent

                    Network {
                        id: networkItem
                        onPopupStateRequested: shouldOpen => root.requestPopupState(networkItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(networkItem, popupOpen)
                    }
                }

                Component {
                    id: audioComponent

                    Volume {
                        id: audioItem
                        onPopupStateRequested: shouldOpen => root.requestPopupState(audioItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(audioItem, popupOpen)
                    }
                }

                Component {
                    id: controlCenterComponent

                    ControlCenter {
                        id: controlCenterItem
                        leftEdgeHitInset: root.configuredLayout.left[0] === "control_center"
                            ? layoutConfig.horizontalPadding : 0
                        rightEdgeHitInset: root.configuredLayout.right[root.configuredLayout.right.length - 1] === "control_center"
                            ? layoutConfig.horizontalPadding : 0
                        tray: barSurface.itemFor("tray")
                        notificationServer: notifications.server
                        doNotDisturb: notifications.doNotDisturb
                        onPopupStateRequested: shouldOpen => root.requestPopupState(controlCenterItem, shouldOpen)
                        onPopupOpenChanged: root.updatePopupOwner(controlCenterItem, popupOpen)
                    }
                }
            }
        }
    }
}
