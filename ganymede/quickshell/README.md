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
- `modules/`: self-contained features, each with its UI and related helpers
  - `bar/`: panel window and composition
  - `audio/`: output and microphone controls
  - `calendar/`: clock calendar popup
  - `budslink/`: budslink companion
  - `network/`: network status and controls
  - `tray/`: system tray and overflow drawer
  - `workspaces/`: workspace indicator and KWin integration service

## Useful commands

```bash
# Validate the configuration without replacing a running shell.
timeout --signal=INT 3s quickshell --path /home/lars/Projects/quickshell
```
