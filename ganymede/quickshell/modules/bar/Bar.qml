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

    function closeActivePopup() {
        if (activePopupOwner)
            activePopupOwner.popupOpen = false
    }

    FileView {
        path: Qt.resolvedUrl("../../bar.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: layoutConfig

            property list<string> left: ["workspace", "appmenu"]
            property list<string> middle: ["clock"]
            property list<string> right: ["media", "tray", "network", "audio", "control_center"]
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

                BarSection {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    itemNames: root.configuredLayout.left
                    barContext: barSurface
                }

                BarSection {
                    id: middleControls

                    anchors.centerIn: parent
                    itemNames: root.configuredLayout.middle
                    barContext: barSurface
                }

                BarSection {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    itemNames: root.configuredLayout.right
                    barContext: barSurface
                }

                Component {
                    id: workspaceComponent

                    Workspace {
                        id: workspaceItem
                        desktopService: workspaces
                        onPopupOpenChanged: root.updatePopupOwner(workspaceItem, popupOpen)
                    }
                }

                Component {
                    id: appMenuComponent

                    AppMenu {
                        id: appMenuItem
                        screen: panel.screen
                        maximumWidth: Math.max(
                            0,
                            panel.width / 2
                                - middleControls.width / 2
                                - 22
                                - (barSurface.itemFor("workspace")?.width || 0)
                        )
                        onPopupOpenChanged: root.updatePopupOwner(appMenuItem, popupOpen)
                    }
                }

                Component {
                    id: clockComponent

                    Clock {
                        id: clockItem
                        onPopupOpenChanged: root.updatePopupOwner(clockItem, popupOpen)
                    }
                }

                Component {
                    id: budsLinkComponent

                    BudsLink {
                        id: budsLinkItem
                        onPopupOpenChanged: root.updatePopupOwner(budsLinkItem, popupOpen)
                    }
                }

                Component {
                    id: mediaComponent

                    MediaControls {
                        id: mediaItem
                        onPopupOpenChanged: root.updatePopupOwner(mediaItem, popupOpen)
                    }
                }

                Component {
                    id: trayComponent

                    Tray {
                        overflowTarget: barSurface.itemFor("control_center")
                        hiddenItemIds: [
                        ]
                    }
                }

                Component {
                    id: networkComponent

                    Network {
                        id: networkItem
                        onPopupOpenChanged: root.updatePopupOwner(networkItem, popupOpen)
                    }
                }

                Component {
                    id: audioComponent

                    Volume {
                        id: audioItem
                        onPopupOpenChanged: root.updatePopupOwner(audioItem, popupOpen)
                    }
                }

                Component {
                    id: controlCenterComponent

                    ControlCenter {
                        id: controlCenterItem
                        tray: barSurface.itemFor("tray")
                        notificationServer: notifications.server
                        doNotDisturb: notifications.doNotDisturb
                        onPopupOpenChanged: root.updatePopupOwner(controlCenterItem, popupOpen)
                    }
                }
            }
        }
    }
}
