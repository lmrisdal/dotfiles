import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import "../bar"

Item {
    id: root

    signal popupStateRequested(bool open)

    property bool popupOpen: false
    readonly property var wifiDevice: connectedDevice(DeviceType.Wifi)
    readonly property var wiredDevice: connectedDevice(DeviceType.Wired)
    readonly property var activeDevice: wiredDevice || wifiDevice
    readonly property var wifiNetwork: wifiDevice
        ? wifiDevice.networks.values.find(network => network.connected)
        : null
    readonly property real signalStrength: wifiNetwork ? wifiNetwork.signalStrength : 0
    readonly property bool connected: wifiDevice !== null || wiredDevice !== null
    property real previousReceivedBytes: -1
    property real previousSentBytes: -1
    property real previousStatsTime: 0
    property string downloadRate: "0 B/s"
    property string uploadRate: "0 B/s"
    readonly property string connectionStatus: {
        if (wiredDevice)
            return `Wired Ethernet: Connected to ${wiredDevice.network ? wiredDevice.network.name : "Wired connection"}`
        if (wifiNetwork)
            return `Wi-Fi: Connected to ${wifiNetwork.name}`
        return "No network connection"
    }
    readonly property string iconName: {
        if (wiredDevice)
            return "network-wired-symbolic"
        if (!wifiDevice)
            return "network-offline-symbolic"
        if (signalStrength < 0.25)
            return "network-wireless-signal-weak-symbolic"
        if (signalStrength < 0.5)
            return "network-wireless-signal-ok-symbolic"
        if (signalStrength < 0.75)
            return "network-wireless-signal-good-symbolic"
        return "network-wireless-signal-excellent-symbolic"
    }

    implicitWidth: 30
    implicitHeight: 40

    function connectedDevice(type) {
        return Networking.devices.values.find(device => device.type === type && device.connected) || null
    }

    function formatRate(bytesPerSecond) {
        const units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
        let value = Math.max(0, bytesPerSecond)
        let unitIndex = 0

        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024
            unitIndex++
        }

        return `${value >= 10 || unitIndex === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[unitIndex]}`
    }

    function refreshNetworkStats() {
        if (activeDevice && !statsQuery.running)
            statsQuery.running = true
    }

    BarIconButton {
        id: networkButton
        anchors.fill: parent
        iconSource: Quickshell.iconPath(root.iconName, "network-offline-symbolic")
        iconColor: root.connected ? "#cdd6f4" : "#6c7086"
        iconOpacity: root.connected ? 1 : 0.7
        popupOpen: root.popupOpen
        onClicked: root.popupStateRequested(!root.popupOpen)
    }

    PopupWindow {
        id: networkPopup
        visible: root.popupOpen
        implicitWidth: 430
        implicitHeight: popupContent.implicitHeight + 28
        color: "transparent"
        grabFocus: true

        anchor {
            item: networkButton
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
            border.color: "#313244"
            border.width: 1
            focus: true

            Keys.onEscapePressed: event => {
                root.popupOpen = false
                event.accepted = true
            }

            Column {
                id: popupContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 4

                Text {
                    text: "Networks"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: root.connectionStatus
                    color: "#cdd6f4"
                    elide: Text.ElideRight
                    font.pixelSize: 13
                }

                Rectangle {
                    width: parent.width
                    height: 9
                    color: "transparent"

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: "#45475a"
                    }
                }

                Text {
                    text: "Network statistics"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    text: `↓ ${root.downloadRate}    ↑ ${root.uploadRate}`
                    color: "#cdd6f4"
                    font.pixelSize: 13
                }
            }
        }
    }

    Process {
        id: statsQuery
        command: ["cat", "/proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.activeDevice)
                    return

                const line = text.split("\n").find(entry => entry.trim().startsWith(`${root.activeDevice.name}:`))
                if (!line)
                    return

                const values = line.split(":")[1].trim().split(/\s+/)
                const receivedBytes = Number(values[0])
                const sentBytes = Number(values[8])
                const now = Date.now()

                if (root.previousStatsTime > 0) {
                    const elapsedSeconds = (now - root.previousStatsTime) / 1000
                    root.downloadRate = root.formatRate((receivedBytes - root.previousReceivedBytes) / elapsedSeconds)
                    root.uploadRate = root.formatRate((sentBytes - root.previousSentBytes) / elapsedSeconds)
                }

                root.previousReceivedBytes = receivedBytes
                root.previousSentBytes = sentBytes
                root.previousStatsTime = now
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.popupOpen
        onRunningChanged: {
            if (running)
                root.refreshNetworkStats()
            else {
                root.previousReceivedBytes = -1
                root.previousSentBytes = -1
                root.previousStatsTime = 0
                root.downloadRate = "0 B/s"
                root.uploadRate = "0 B/s"
            }
        }
        onTriggered: root.refreshNetworkStats()
    }
}
