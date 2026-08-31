import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland._ToplevelManagement
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    signal popupStateRequested(bool open)

    readonly property var player: Mpris.players.values.find(candidate => candidate.isPlaying)
        || Mpris.players.values.find(candidate => candidate.playbackState === MprisPlaybackState.Paused)
        || null
    readonly property bool hasMedia: player !== null
        && player.playbackState !== MprisPlaybackState.Stopped
    readonly property string title: player && player.trackTitle ? player.trackTitle : "Unknown track"
    readonly property string artist: player && player.trackArtist ? player.trackArtist : "Unknown artist"
    readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property var sourceDesktopEntry: {
        if (!player)
            return null

        return DesktopEntries.byId(player.desktopEntry)
            || DesktopEntries.byId(`${player.desktopEntry}.desktop`)
            || DesktopEntries.heuristicLookup(player.identity)
    }
    readonly property var sourceToplevel: {
        if (!player)
            return null

        const targets = [
            player.desktopEntry,
            sourceDesktopEntry ? sourceDesktopEntry.id : "",
            sourceDesktopEntry ? sourceDesktopEntry.startupClass : "",
            player.identity,
        ].map(value => normalizedAppId(value)).filter(value => value !== "")

        return ToplevelManager.toplevels.values.find(toplevel => {
            const appId = normalizedAppId(toplevel.appId)
            return targets.some(target => appId === target
                || appId.endsWith(`.${target}`)
                || target.endsWith(`.${appId}`))
        }) || null
    }
    readonly property string sourceQuery: sourceDesktopEntry && sourceDesktopEntry.name
        ? sourceDesktopEntry.name
        : player && player.identity ? player.identity
        : player ? player.desktopEntry
        : ""
    readonly property string desktopSession: `${Quickshell.env("XDG_CURRENT_DESKTOP") || ""}:${Quickshell.env("XDG_SESSION_DESKTOP") || ""}`.toLowerCase()
    readonly property bool isKdeSession: desktopSession.includes("kde")
        || desktopSession.includes("plasma")
    readonly property bool canOpenSource: player !== null
        && (sourceToplevel !== null || player.canRaise || sourceDesktopEntry !== null)
    property bool popupOpen: false

    visible: hasMedia
    implicitWidth: visible ? 326 : 0
    implicitHeight: 40

    onHasMediaChanged: {
        if (!hasMedia)
            popupOpen = false
    }

    function normalizedAppId(value) {
        if (!value)
            return ""

        return value.toLowerCase().replace(/\.desktop$/, "")
    }

    function openSourceApp() {
        if (!player)
            return

        if (isKdeSession && sourceQuery && !windowMatchProcess.running) {
            windowMatchProcess.command = [
                "busctl",
                "--user",
                "--json=short",
                "call",
                "org.kde.KWin",
                "/WindowsRunner",
                "org.kde.krunner1",
                "Match",
                "s",
                sourceQuery,
            ]
            windowMatchProcess.running = true
        } else {
            openSourceFallback()
        }

        popupOpen = false
    }

    function openSourceFallback() {
        if (sourceToplevel)
            sourceToplevel.activate()
        else if (player.canRaise)
            player.raise()
        else if (sourceDesktopEntry)
            sourceDesktopEntry.execute()

    }

    Process {
        id: windowMatchProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    const matches = response.data && response.data[0]
                    const resultId = matches && matches.length > 0 ? matches[0][0] : ""

                    if (resultId) {
                        windowRunProcess.command = [
                            "busctl",
                            "--user",
                            "call",
                            "org.kde.KWin",
                            "/WindowsRunner",
                            "org.kde.krunner1",
                            "Run",
                            "ss",
                            resultId,
                            "",
                        ]
                        windowRunProcess.running = true
                        return
                    }
                } catch (error) {
                    console.warn("Failed to read KWin window match:", error)
                }

                root.openSourceFallback()
            }
        }
    }

    Process {
        id: windowRunProcess
    }

    component MarqueeLabel: Item {
        id: marquee

        required property string label
        property color labelColor: "#cdd6f4"
        property int pixelSize: 13
        property bool bold: false
        property bool centerWhenShort: false
        readonly property bool overflowing: marqueeText.implicitWidth > width
        readonly property real travelDistance: Math.max(0, marqueeText.implicitWidth - width)

        clip: true

        Text {
            id: marqueeText
            x: !marquee.overflowing && marquee.centerWhenShort
                ? (marquee.width - implicitWidth) / 2
                : 0
            anchors.verticalCenter: parent.verticalCenter
            text: marquee.label
            color: marquee.labelColor
            font.pixelSize: marquee.pixelSize
            font.bold: marquee.bold

            transform: Translate {
                id: marqueeOffset
            }
        }

        SequentialAnimation {
            running: marquee.overflowing
            loops: Animation.Infinite

            onRunningChanged: {
                if (!running)
                    marqueeOffset.x = 0
            }

            PauseAnimation {
                duration: 1200
            }

            NumberAnimation {
                target: marqueeOffset
                property: "x"
                to: -marquee.travelDistance
                duration: Math.max(700, Math.round(marquee.travelDistance / 35 * 1000))
                easing.type: Easing.InOutSine
            }

            PauseAnimation {
                duration: 1200
            }

            NumberAnimation {
                target: marqueeOffset
                property: "x"
                to: 0
                duration: Math.max(700, Math.round(marquee.travelDistance / 35 * 1000))
                easing.type: Easing.InOutSine
            }
        }
    }

    component MediaButton: Item {
        id: mediaControl

        required property string iconName
        property bool controlEnabled: true
        signal activated()

        width: 32
        height: 40
        opacity: controlEnabled ? 1 : 0.45

        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 24
            radius: height / 2
            color: controlMouse.pressed ? "#585b70" : "transparent"
        }

        IconImage {
            id: controlIcon
            anchors.centerIn: parent
            width: 18
            height: 18
            source: Quickshell.iconPath(mediaControl.iconName)
            visible: false
        }

        ColorOverlay {
            anchors.fill: controlIcon
            source: controlIcon
            color: mediaControl.controlEnabled ? "#cdd6f4" : "#6c7086"
        }

        MouseArea {
            id: controlMouse
            anchors.fill: parent
            enabled: mediaControl.controlEnabled
            onClicked: mediaControl.activated()
        }
    }

    Rectangle {
        id: mediaButton
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: height / 2
            color: mediaInfoMouse.pressed || root.popupOpen ? "#585b70" : "transparent"
        }

        Row {
            anchors.fill: parent
            spacing: 0

            Item {
                width: 14
                height: parent.height
            }

            MarqueeLabel {
                width: 202
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                label: `${root.title}  —  ${root.artist}`
                bold: true
            }

            MediaButton {
                iconName: "media-skip-backward-symbolic"
                controlEnabled: root.player ? root.player.canGoPrevious : false
                onActivated: root.player.previous()
            }

            MediaButton {
                iconName: root.player && root.player.isPlaying
                    ? "media-playback-pause-symbolic"
                    : "media-playback-start-symbolic"
                controlEnabled: root.player ? root.player.canTogglePlaying : false
                onActivated: root.player.togglePlaying()
            }

            MediaButton {
                iconName: "media-skip-forward-symbolic"
                controlEnabled: root.player ? root.player.canGoNext : false
                onActivated: root.player.next()
            }
        }

        MouseArea {
            id: mediaInfoMouse
            x: 4
            y: 0
            width: 220
            height: parent.height
            hoverEnabled: true
            onClicked: root.popupStateRequested(!root.popupOpen)
        }
    }

    PopupWindow {
        id: mediaPopup
        visible: root.popupOpen && root.hasMedia
        implicitWidth: 312
        implicitHeight: popupContent.implicitHeight + 28
        color: "transparent"
        grabFocus: true

        anchor {
            item: mediaButton
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

            MouseArea {
                anchors.fill: parent
                enabled: root.canOpenSource
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openSourceApp()
            }

            Column {
                id: popupContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: width
                    radius: 7
                    color: "#313244"
                    clip: true

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    IconImage {
                        id: fallbackArtIcon
                        anchors.centerIn: parent
                        width: 64
                        height: 64
                        source: Quickshell.iconPath("audio-x-generic-symbolic")
                        visible: albumArt.status !== Image.Ready
                    }

                    ColorOverlay {
                        anchors.fill: fallbackArtIcon
                        source: fallbackArtIcon
                        color: "#6c7086"
                        visible: fallbackArtIcon.visible
                    }
                }

                MarqueeLabel {
                    width: parent.width
                    height: 22
                    label: root.title
                    pixelSize: 16
                    bold: true
                    centerWhenShort: true
                }

                MarqueeLabel {
                    width: parent.width
                    height: 19
                    label: root.album ? `${root.artist} — ${root.album}` : root.artist
                    labelColor: "#a6adc8"
                    centerWhenShort: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    MediaButton {
                        iconName: "media-skip-backward-symbolic"
                        controlEnabled: root.player ? root.player.canGoPrevious : false
                        onActivated: root.player.previous()
                    }

                    MediaButton {
                        iconName: root.player && root.player.isPlaying
                            ? "media-playback-pause-symbolic"
                            : "media-playback-start-symbolic"
                        controlEnabled: root.player ? root.player.canTogglePlaying : false
                        onActivated: root.player.togglePlaying()
                    }

                    MediaButton {
                        iconName: "media-skip-forward-symbolic"
                        controlEnabled: root.player ? root.player.canGoNext : false
                        onActivated: root.player.next()
                    }
                }
            }
        }
    }
}
