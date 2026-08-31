# Quickshell configuration guidelines

## Project context

- This directory is the live configuration: `~/.config/quickshell` is a symlink
  to `/home/lars/Projects/dotfiles/ganymede/quickshell`.
- Target environment: KDE Plasma on Wayland, CachyOS/Arch, Quickshell 0.3.x.
- Do not modify Plasma panels, Autostart, or other desktop settings unless the
  user explicitly asks. Keep the Plasma panel as a fallback while this shell is
  developed.

## Architecture

- Keep `shell.qml` as the minimal entry point. Compose long-lived features from
  it through focused, upper-camel-case QML components such as `Bar.qml` and
  `Tray.qml`.
- Each visual feature belongs in its own QML file. Keep OS/service integration
  close to the component that consumes it; extract shared state into a singleton
  only when two or more components need it.
- Use `PanelWindow` for bars and `PopupWindow` anchored to a control for menus
  and drawers. Use `Variants` over `Quickshell.screens` for per-monitor panels.
- Preserve the existing Catppuccin-style palette unless the user requests a
  visual redesign.
- Keep all bar controls visually consistent: use `#cdd6f4` for active icons,
  `#6c7086` for unavailable or disconnected icons, and `#313244` for hover
  surfaces. Tint system-theme icons explicitly instead of inheriting their
  arbitrary theme colors.
- Give clicked bar controls a macOS-like inset pill using `#585b70`. Keep that
  pill visible while the control's popup is open, not only while the pointer is
  pressed, and use half the pill height as its radius.
- Keep a control's hit target separate from its visible pressed/open surface.
  The hit target may fill the bar height or reach a screen edge, but the pill
  must remain inset on every side. In particular, the Control Center must stay
  clickable from the top-right screen corner without its background touching
  the top or right edge.
- Give the clock pill generous horizontal padding: size its hit target to the
  content width plus 16 pixels while keeping the visible pill inset by 4 pixels.
- Build standard icon controls from `BarIconButton.qml` and standard text
  controls from `BarTextButton.qml` so their hit targets, pressed pills, content
  padding, and edge-hit behavior remain consistent. Compound controls such as
  Workspaces and Tray may keep natural content widths.
- Keep visible tray icons at 22 pixels and pack their item containers tightly.
  Tray pressed surfaces must be circles or, preferably, horizontal pills—never
  vertical capsules. The current tray treatment uses 30-pixel-wide containers,
  no row spacing, and a 28-by-24-pixel pressed pill.
- All bar components and sections must respect the global `itemSpacing` property
  from `bar.json`. Do not hardcode per-component or per-section gaps that bypass
  this setting; reserve component-local spacing for content within a component.

## QML and Quickshell conventions

- Use four-space indentation, double-quoted strings, and descriptive `id`s.
- Import only the modules a file uses. Prefer Quickshell services and Qt APIs to
  polling shell commands.
- Treat reactive bindings as the default. Do not create timers or external
  processes for information Quickshell exposes natively.
- Use `Quickshell.Services.Pipewire` plus `PwObjectTracker` for audio controls;
  volume and mute access require the selected PipeWire node to be bound.
- Tray behavior: items with `Status.Passive`, or an ID listed in
  `Tray.hiddenItemIds`, belong in the overflow drawer; `Active` and
  `NeedsAttention` otherwise stay visible. Preserve left, middle, and right
  click semantics for every tray icon.
- The tray has a user-defined display order persisted in Quickshell state. Do
  not reorder `SystemTray.items` directly; reorder the rendered model instead.
  Manual hide/show operations are persisted in the same state file.
- Every bar popup must close when Escape is pressed and when the user clicks an
  unoccupied area of the bar. Keep its open state on the owning control so the
  bar can dismiss it alongside other popups.

## Verification

- Validate every QML edit from this repository before handing it off:

  ```bash
  timeout --signal=INT 3s quickshell --path /home/lars/Projects/dotfiles/ganymede/quickshell
  ```

  Exit status `124` is expected because `timeout` stops the running shell. The
  important result is `Configuration Loaded` with no QML errors.
- Quickshell live-reloads while running. Do not use `pkill quickshell` or change
  the user’s currently running shell without clear authorization.
