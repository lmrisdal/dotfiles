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

## Useful commands

```bash
# Validate the configuration without replacing a running shell.
timeout --signal=INT 3s quickshell --path /home/lars/Projects/dotfiles/ganymede/quickshell
```
