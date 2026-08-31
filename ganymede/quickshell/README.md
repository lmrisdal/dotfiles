# Quickshell Plasma bar

This directory is the live Quickshell configuration. It is symlinked to
`~/.config/quickshell`, so changes here are picked up by Quickshell on save.

## Run while developing

```bash
quickshell
```

The initial config renders a small top bar on every connected screen. Keep the
existing Plasma panel enabled until the replacement has the features you need.

## Layout

- `shell.qml`: config entry point
- `bar.json`: ordered items in the left, middle, and right bar sections
- `modules/`: self-contained features, each with its UI and related helpers
  - `bar/`: panel window and composition
  - `audio/`: output and microphone controls
  - `calendar/`: clock calendar popup
  - `budslink/`: budslink companion
  - `network/`: network status and controls
  - `tray/`: system tray and overflow drawer
  - `workspaces/`: workspace indicator and KWin integration service

## Configure the bar

Edit `bar.json` to move, hide, or reorder bar items. Changes are reloaded while
Quickshell is running.

```json
{
    "left": ["workspace", "appmenu"],
    "middle": ["clock"],
    "right": ["media", "tray", "network", "audio", "control_center"]
}
```

Available item names are `workspace`, `appmenu`, `clock`, `budslink`, `media`,
`tray`, `network`, `audio`, and `control_center`. Each item can occur at most
once. Unknown and duplicate names are ignored with a warning.

## Build the application-menu helper

The application-menu feature uses a small local Qt 6 companion process. Build
it after cloning the dotfiles and again after Qt or Plasma upgrades:

```bash
cmake -S native/appmenu -B build/appmenu-native -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build/appmenu-native --parallel
```

The executable stays in the ignored `build/appmenu-native` directory and needs
no system installation. The application-name fallback remains usable if the
helper has not been built. Restart Quickshell after rebuilding so its running
helper process uses the new executable; otherwise the next login will pick it
up automatically.

The helper vendors KDE's small DBusMenu importer from Plasma Workspace 6.7.4.
Its provenance and license details are recorded in
`native/appmenu/dbusmenuqt/README.md`.

## Useful commands

```bash
# Validate the configuration without replacing a running shell.
timeout --signal=INT 3s quickshell --path /home/lars/Projects/dotfiles/ganymede/quickshell
```
