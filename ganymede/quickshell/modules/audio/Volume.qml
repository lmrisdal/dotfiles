import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var microphone: source ? source.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool microphoneMuted: microphone ? microphone.muted : false
    readonly property real microphoneVolume: microphone ? microphone.volume : 0
    property bool popupOpen: false
    readonly property string iconName: {
        if (!audio || muted)
            return "audio-volume-muted-symbolic"
        if (volume < 0.33)
            return "audio-volume-low-symbolic"
        if (volume < 0.67)
            return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

    implicitWidth: 22
    implicitHeight: 22

    PwObjectTracker {
        objects: [root.sink, root.source].concat(Pipewire.nodes.values)
    }

    function setVolume(value) {
        if (audio)
            audio.volume = Math.max(0, Math.min(1, value))
    }

    function adjustVolume(delta) {
        setVolume(volume + delta)
    }

    function setMicrophoneVolume(value) {
        if (microphone)
            microphone.volume = Math.max(0, Math.min(1, value))
    }

    Rectangle {
        id: volumeButton
        anchors.fill: parent
        radius: 4
        color: volumeMouse.containsMouse ? "#313244" : "transparent"

        IconImage {
            id: volumeIcon
            anchors.fill: parent
            source: Quickshell.iconPath(root.iconName, "audio-volume-high-symbolic")
            visible: false
        }

        ColorOverlay {
            anchors.fill: parent
            source: volumeIcon
            color: root.audio ? "#cdd6f4" : "#6c7086"
            opacity: root.audio ? 1 : 0.7
        }

        MouseArea {
            id: volumeMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.audio !== null
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.popupOpen = !root.popupOpen
                else if (mouse.button === Qt.MiddleButton)
                    root.audio.muted = !root.audio.muted
            }
            onWheel: wheel => root.adjustVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    PopupWindow {
        id: volumePopup
        visible: root.popupOpen
        implicitWidth: 360
        implicitHeight: outputDevices.visible || inputDevices.visible ? 338 : 248
        color: "transparent"
        grabFocus: true

        anchor {
            item: volumeButton
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
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Text {
                    text: "Output"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 5
                    color: outputDeviceMouse.containsMouse ? "#313244" : "#45475a"

                    Text {
                        anchors.left: parent.left
                        anchors.right: outputChevron.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        text: root.sink ? root.sink.description : "No output device"
                        color: "#cdd6f4"
                        elide: Text.ElideRight
                        font.pixelSize: 13
                    }

                    Text {
                        id: outputChevron
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: outputDevices.visible ? "⌃" : "⌄"
                        color: "#bac2de"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: outputDeviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            outputDevices.visible = !outputDevices.visible
                            inputDevices.visible = false
                        }
                    }
                }

                ListView {
                    id: outputDevices
                    visible: false
                    width: parent.width
                    height: visible ? Math.min(contentHeight, 96) : 0
                    clip: true
                    spacing: 2
                    model: ScriptModel {
                        values: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink)
                    }

                    delegate: Rectangle {
                        required property var modelData
                        width: outputDevices.width
                        height: 30
                        radius: 4
                        color: outputChoiceMouse.containsMouse ? "#313244" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            text: modelData.description || modelData.name
                            color: modelData === root.sink ? "#89b4fa" : "#cdd6f4"
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: outputChoiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Pipewire.preferredDefaultAudioSink = modelData
                                outputDevices.visible = false
                            }
                        }
                    }
                }

                Text {
                    text: root.muted ? "Muted" : `${Math.round(root.volume * 100)}%`
                    color: "#a6adc8"
                    font.pixelSize: 13
                }

                Rectangle {
                    id: sliderTrack
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#45475a"

                    Rectangle {
                        width: parent.width * (root.muted ? 0 : root.volume)
                        height: parent.height
                        radius: parent.radius
                        color: "#89b4fa"
                    }

                    Rectangle {
                        x: parent.width * (root.muted ? 0 : root.volume) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        radius: 7
                        color: "#cdd6f4"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        enabled: root.audio !== null

                        function updateVolume(mouse) {
                            root.setVolume(mouse.x / width)
                        }

                        onPressed: mouse => updateVolume(mouse)
                        onPositionChanged: mouse => {
                            if (pressed)
                                updateVolume(mouse)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 4
                }

                Text {
                    text: "Input"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 5
                    color: inputDeviceMouse.containsMouse ? "#313244" : "#45475a"

                    Text {
                        anchors.left: parent.left
                        anchors.right: inputChevron.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        text: root.source ? root.source.description : "No input device"
                        color: "#cdd6f4"
                        elide: Text.ElideRight
                        font.pixelSize: 13
                    }

                    Text {
                        id: inputChevron
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: inputDevices.visible ? "⌃" : "⌄"
                        color: "#bac2de"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: inputDeviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            inputDevices.visible = !inputDevices.visible
                            outputDevices.visible = false
                        }
                    }
                }

                ListView {
                    id: inputDevices
                    visible: false
                    width: parent.width
                    height: visible ? Math.min(contentHeight, 96) : 0
                    clip: true
                    spacing: 2
                    model: ScriptModel {
                        values: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && !node.isSink)
                    }

                    delegate: Rectangle {
                        required property var modelData
                        width: inputDevices.width
                        height: 30
                        radius: 4
                        color: inputChoiceMouse.containsMouse ? "#313244" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            text: modelData.description || modelData.name
                            color: modelData === root.source ? "#f5c2e7" : "#cdd6f4"
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: inputChoiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Pipewire.preferredDefaultAudioSource = modelData
                                inputDevices.visible = false
                            }
                        }
                    }
                }

                Text {
                    text: root.microphoneMuted ? "Microphone muted" : `Microphone ${Math.round(root.microphoneVolume * 100)}%`
                    color: "#a6adc8"
                    font.pixelSize: 13
                }

                Rectangle {
                    id: microphoneTrack
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#45475a"

                    Rectangle {
                        width: parent.width * (root.microphoneMuted ? 0 : root.microphoneVolume)
                        height: parent.height
                        radius: parent.radius
                        color: "#f5c2e7"
                    }

                    Rectangle {
                        x: parent.width * (root.microphoneMuted ? 0 : root.microphoneVolume) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        radius: 7
                        color: "#cdd6f4"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        enabled: root.microphone !== null
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        function updateVolume(mouse) {
                            root.setMicrophoneVolume(mouse.x / width)
                        }

                        onPressed: mouse => updateVolume(mouse)
                        onPositionChanged: mouse => {
                            if (pressed)
                                updateVolume(mouse)
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton)
                                root.microphone.muted = !root.microphone.muted
                        }
                    }
                }
            }
        }
    }
}
