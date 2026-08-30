import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var devices: ({})
    property string selectedPath: ""
    property bool popupOpen: false
    property string iconDirectory: ""
    property string notifiedVersion: ""
    readonly property var activeDevice: selectedPath ? devices[selectedPath] : null
    readonly property bool available: activeDevice !== null
    readonly property var config: activeDevice ? activeDevice.config : ({})
    readonly property var state: activeDevice ? activeDevice.state : ({})
    readonly property int battery: state.computedBatteryLevel ?? 0

    implicitWidth: available ? batteryText.implicitWidth + 39 : 0
    implicitHeight: 40
    visible: available

    function iconUrl(iconName) {
        if (!iconName)
            return ""

        let fileName = iconName.startsWith("bbm-") ? iconName : `bbm-${iconName}`
        if (!fileName.endsWith("-symbolic") && !fileName.endsWith("-symbolic.svg"))
            fileName += "-symbolic"
        if (!fileName.endsWith(".svg"))
            fileName += ".svg"
        return iconDirectory ? `file://${iconDirectory}/${fileName}` : ""
    }

    component SymbolicIcon: Item {
        property url iconSource
        property color iconColor: "#cdd6f4"

        Image {
            id: sourceImage
            anchors.fill: parent
            source: parent.iconSource
            fillMode: Image.PreserveAspectFit
            visible: false
        }

        ColorOverlay {
            anchors.fill: parent
            source: sourceImage
            color: parent.iconColor
        }
    }

    function selectDevice() {
        const paths = Object.keys(devices)
        selectedPath = paths.length > 0 ? paths[0] : ""
    }

    function updateDevice(path, alias, config, state) {
        const previous = devices[path] || {}
        const updated = {}
        for (const key in devices)
            updated[key] = devices[key]
        updated[path] = {
            alias: alias === null ? previous.alias : alias,
            config: config === null ? previous.config : config,
            state: state === null ? previous.state : state
        }
        devices = updated
        if (!selectedPath)
            selectDevice()
    }

    function removeDevice(path) {
        const updated = {}
        for (const key in devices)
            updated[key] = devices[key]
        delete updated[path]
        devices = updated
        if (selectedPath === path)
            selectDevice()
    }

    function callUiAction(action, value) {
        if (!selectedPath)
            return
        actionProcess.exec([
            "busctl", "--user", "call", "io.github.maniacx.BudsLink", selectedPath,
            "io.github.maniacx.BudsLink.Device", "UiAction", "si", action, String(value)
        ])
    }

    function notifyIncompatibleVersion(expected, actual) {
        if (notifiedVersion === actual)
            return
        notifiedVersion = actual
        notificationProcess.exec([
            "notify-send",
            "--app-name=BudsLink",
            "BudsLink update needs attention",
            `BudsLink D-Bus version ${actual} is unsupported (expected ${expected}). Update the Quickshell BudsLink bridge.`
        ])
    }

    Process {
        id: bridge
        command: ["/usr/bin/python3", Quickshell.shellPath("modules/budslink/BudsLinkBridge.py")]
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    if (message.event === "device-added" || message.event === "device-updated")
                        root.updateDevice(message.path, message.alias, message.config, message.state)
                    else if (message.event === "device-removed")
                        root.removeDevice(message.path)
                    else if (message.event === "unavailable")
                        root.devices = ({})
                    else if (message.event === "incompatible-version")
                        root.notifyIncompatibleVersion(message.expected, message.actual)
                } catch (error) {
                    console.warn("Ignoring invalid BudsLink bridge event:", error)
                }
            }
        }
    }

    Process {
        id: actionProcess
    }

    Process {
        id: notificationProcess
    }

    Process {
        id: iconDirectoryQuery
        command: ["flatpak", "info", "--show-location", "io.github.maniacx.BudsLink"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const installLocation = data.trim()
                if (installLocation)
                    root.iconDirectory = `${installLocation}/files/share/icons/hicolor/scalable/actions`
            }
        }
    }

    Rectangle {
        id: budsButton
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            anchors.topMargin: 5
            anchors.bottomMargin: 5
            radius: height / 2
            color: budsMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
        }

        SymbolicIcon {
            id: budsIcon
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            iconSource: root.iconUrl(root.config.commonIcon)
        }

        Text {
            id: batteryText
            anchors.left: budsIcon.right
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.battery}%`
            color: "#cdd6f4"
            font.pixelSize: 11
        }

        MouseArea {
            id: budsMouse
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
        }
    }

    PopupWindow {
        id: budsPopup
        visible: root.popupOpen && root.available
        implicitWidth: 330
        implicitHeight: popupContent.implicitHeight + 28
        color: "transparent"
        grabFocus: true

        anchor {
            item: budsButton
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            adjustment: PopupAdjustment.All
        }

        onVisibleChanged: {
            if (!visible)
                root.popupOpen = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            focus: true

            Keys.onEscapePressed: event => {
                root.popupOpen = false
                event.accepted = true
            }

            Column {
                id: popupContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 14

                Text {
                    width: parent.width
                    text: root.activeDevice ? root.activeDevice.alias : "BudsLink"
                    color: "#cdd6f4"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Row {
                    spacing: 18
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: [
                            {
                                index: 1,
                                label: "Left",
                                level: root.state.battery1Level,
                                status: root.state.battery1Status,
                                showOnDisconnect: root.config.battery1ShowOnDisconnect
                            },
                            {
                                index: 2,
                                label: "Right",
                                level: root.state.battery2Level,
                                status: root.state.battery2Status,
                                showOnDisconnect: root.config.battery2ShowOnDisconnect
                            },
                            {
                                index: 3,
                                label: "Case",
                                level: root.state.battery3Level,
                                status: root.state.battery3Status,
                                showOnDisconnect: root.config.battery3ShowOnDisconnect
                            }
                        ].filter(entry => entry.level > 0
                            && (entry.showOnDisconnect === true || entry.status !== "disconnected"))

                        delegate: Column {
                            required property var modelData
                            spacing: 3

                            SymbolicIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 20
                                height: 20
                                iconSource: root.iconUrl(root.config[`battery${modelData.index}Icon`])
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: "#a6adc8"
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${modelData.level}%`
                                color: "#cdd6f4"
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 7
                    visible: root.state.toggle1Visible === true && root.config.toggle1Button1Name

                    Text {
                        text: root.config.toggle1Title || "Noise Control"
                        color: "#a6adc8"
                        font.pixelSize: 12
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [1, 2, 3, 4].filter(index => root.config[`toggle1Button${index}Name`])

                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool selected: root.state.toggle1State === modelData
                                width: (parent.width - parent.spacing * 3) / 4
                                height: 30
                                radius: 5
                                color: selected ? "#585b70" : "#313244"

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    iconSource: root.iconUrl(root.config[`toggle1Button${modelData}Icon`])
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.callUiAction("toggle1State", modelData)
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 7
                    visible: root.state.toggle2Visible === true && root.config.toggle2Button1Name

                    Text {
                        text: root.config.toggle2Title || "Device control"
                        color: "#a6adc8"
                        font.pixelSize: 12
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [1, 2, 3, 4].filter(index => root.config[`toggle2Button${index}Name`])

                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool selected: root.state.toggle2State === modelData
                                width: (parent.width - parent.spacing) / 2
                                height: 30
                                radius: 5
                                color: selected ? "#585b70" : "#313244"

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    iconSource: root.iconUrl(root.config[`toggle2Button${modelData}Icon`])
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.callUiAction("toggle2State", modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 5
                    color: settingsMouse.containsMouse ? "#45475a" : "#313244"
                    visible: root.config.showSettingsButton === true

                    Text {
                        anchors.centerIn: parent
                        text: "Open BudsLink settings"
                        color: "#cdd6f4"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.callUiAction("settingsButtonClicked", 0)
                    }
                }
            }
        }
    }
}
