import Quickshell
import Quickshell.Networking
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property bool popupOpen: false
    readonly property var wifiDevice: connectedDevice(DeviceType.Wifi)
    readonly property var wiredDevice: connectedDevice(DeviceType.Wired)
    readonly property var wifiNetwork: wifiDevice
        ? wifiDevice.networks.values.find(network => network.connected)
        : null
    readonly property real signalStrength: wifiNetwork ? wifiNetwork.signalStrength : 0
    readonly property bool connected: wifiDevice !== null || wiredDevice !== null
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

    implicitWidth: 22
    implicitHeight: 22

    function connectedDevice(type) {
        return Networking.devices.values.find(device => device.type === type && device.connected) || null
    }

    function openSettings() {
        Quickshell.execDetached(["kcmshell6", "kcm_networkmanagement"])
    }

    function toggleAirplaneMode() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    Rectangle {
        id: networkButton
        anchors.fill: parent
        radius: 4
        color: networkMouse.containsMouse ? "#313244" : "transparent"

        IconImage {
            id: networkIcon
            anchors.fill: parent
            source: Quickshell.iconPath(root.iconName, "network-offline-symbolic")
            visible: false
        }

        ColorOverlay {
            anchors.fill: parent
            source: networkIcon
            color: root.connected ? "#cdd6f4" : "#6c7086"
            opacity: root.connected ? 1 : 0.7
        }

        MouseArea {
            id: networkMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onContainsMouseChanged: root.popupOpen = containsMouse

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.openSettings()
                else if (mouse.button === Qt.MiddleButton)
                    root.toggleAirplaneMode()
            }
        }
    }

    PopupWindow {
        id: networkPopup
        visible: root.popupOpen
        implicitWidth: 430
        implicitHeight: 116
        color: "transparent"

        anchor {
            item: networkButton
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            adjustment: PopupAdjustment.All
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#1e1e2e"
            border.color: "#313244"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                Text {
                    text: "Networks"
                    color: "#cdd6f4"
                    font.family: "monospace"
                    font.pixelSize: 21
                }

                Text {
                    width: parent.width
                    text: root.connectionStatus
                    color: "#bac2de"
                    elide: Text.ElideRight
                    font.family: "monospace"
                    font.pixelSize: 16
                }

                Text {
                    text: Networking.wifiEnabled
                        ? "Middle-click to turn off Wi-Fi"
                        : "Middle-click to turn on Wi-Fi"
                    color: "#bac2de"
                    font.family: "monospace"
                    font.pixelSize: 16
                }
            }
        }
    }
}
