import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var desktops: []
    property string currentDesktopId: ""

    function refresh() {
        desktopQuery.running = true
    }

    function switchTo(desktopId) {
        if (desktopId === currentDesktopId)
            return

        Quickshell.execDetached([
            "qdbus6",
            "org.kde.KWin",
            "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager.current",
            desktopId,
        ])
    }

    function addDesktop() {
        Quickshell.execDetached([
            "qdbus6",
            "org.kde.KWin",
            "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager.createDesktop",
            desktops.length.toString(),
            "Desktop " + (desktops.length + 1),
        ])
    }

    function removeDesktop(desktopId) {
        if (desktops.length <= 1)
            return

        Quickshell.execDetached([
            "qdbus6",
            "org.kde.KWin",
            "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager.removeDesktop",
            desktopId,
        ])
    }

    Process {
        id: desktopQuery
        running: true
        command: [
            "sh",
            "-c",
            "busctl --user --json=short get-property org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager desktops && busctl --user --json=short get-property org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager current",
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                if (lines.length !== 2)
                    return

                try {
                    const desktopData = JSON.parse(lines[0]).data
                    const currentDesktop = JSON.parse(lines[1]).data

                    root.desktops = desktopData.map(desktop => ({
                        position: desktop[0],
                        id: desktop[1],
                        name: desktop[2],
                    }))
                    root.currentDesktopId = currentDesktop
                } catch (error) {
                    console.warn("Failed to read virtual desktops:", error)
                }
            }
        }
    }

    Process {
        command: [
            "dbus-monitor",
            "--session",
            "type='signal',sender='org.kde.KWin',path='/VirtualDesktopManager',interface='org.kde.KWin.VirtualDesktopManager'",
        ]
        running: true

        stdout: SplitParser {
            onRead: message => {
                if (message.startsWith("signal "))
                    root.refresh()
            }
        }
    }

}
