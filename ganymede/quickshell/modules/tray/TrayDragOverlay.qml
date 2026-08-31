import Quickshell
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: root

    required property var shellScreen
    required property bool dragActive
    required property url iconSource
    required property real iconX
    required property real iconY
    required property bool removeCandidate

    screen: shellScreen
    visible: true
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: emptyInputRegion }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    Item {
        id: emptyInputRegion
        width: 0
        height: 0
    }

    Item {
        id: dragGhost
        visible: root.dragActive
        x: root.iconX
        y: root.iconY
        width: 22
        height: 22

        IconImage {
            anchors.fill: parent
            source: root.iconSource
        }

        Item {
            id: removeCallout
            visible: root.removeCandidate
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(-dragGhost.y + 4, -height - 8)
            width: removeLabel.width
            height: removeLabel.height + removeArrow.height

            Rectangle {
                id: removeLabel
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: removeText.implicitWidth + 20
                height: 28
                radius: 6
                color: "#313244"

                Text {
                    id: removeText
                    anchors.centerIn: parent
                    text: "Remove"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Rectangle {
                id: removeArrow
                anchors.top: removeLabel.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 8
                height: 8
                color: "#313244"
                rotation: 45
                transformOrigin: Item.Center
            }
        }
    }
}
