# Quickshell application menu plan

## Goal

Build a Quickshell-native global application menu for KDE Plasma on Wayland.
The finished component should show the active application's top-level menu
entries in the bar and open the application's exported DBusMenu when an entry
is selected.

Development is deliberately incremental. The first milestone only displays the
active application name. It does not register as a global-menu viewer, import a
DBusMenu, or make the label clickable.

## Constraints

- Keep `shell.qml` as the minimal entry point.
- Put the visual feature in `modules/appmenu/AppMenu.qml`.
- Integrate it into the left side of `modules/bar/Bar.qml`, immediately after
  the workspace control.
- Preserve the current Catppuccin-style palette and 40-pixel bar height.
- Keep the existing Plasma panel and appmenu applet available as a fallback
  while this feature is incomplete.
- Do not restart or kill the live Quickshell process during development.
- Validate every QML change with:

  ```bash
  timeout --signal=INT 3s quickshell --path /home/lars/Projects/dotfiles/ganymede/quickshell
  ```

  Exit status `124` is expected. Success means the output contains
  `Configuration Loaded` and no QML errors.

## Relevant upstream design

KDE's applet divides the work into three pieces:

1. `TaskManager::TasksModel` tracks the active task and exposes its application
   menu service name and object path.
2. `DBusMenuImporter` turns that service/path pair into a tree of `QAction` and
   `QMenu` objects.
3. QML renders the top-level actions while the applet controller opens the
   corresponding native `QMenu` at the clicked item's screen position.

The native applet also owns the session-bus name `org.kde.kappmenuview`. KDE's
KDED appmenu module watches for this name and only provides
`com.canonical.AppMenu.Registrar` while a global-menu viewer exists. A complete
Quickshell implementation must reproduce that lifecycle.

Quickshell 0.3.1 provides active-toplevel information and internal DBusMenu
types, but its `DBusMenuHandle` cannot be constructed from QML using an
arbitrary service and object path. Consequently, milestone 1 can be pure QML,
while the actual global menu will need a small native bridge or companion
process.

## Milestone 1: show the active application name

### Scope

Create a passive label that follows the currently active Wayland toplevel. It
will be present on every bar and will show the same active application, matching
the upstream applet's default `allScreens: true` behavior.

### Files

- Add `modules/appmenu/AppMenu.qml`.
- Update `modules/bar/Bar.qml` to import `../appmenu`.
- Instantiate `AppMenu` in `leftControls`, after `Workspace`.

No helper process, C++, build system, state file, or popup is needed in this
milestone.

### Data source

Use KDE's `org.kde.taskmanager` QML module and bind to `TasksModel.activeTask`.
KWin restricts the underlying window-management protocol to approved desktop
applications. Before this binding can work, a desktop entry whose absolute
`Exec` path matches `/usr/bin/quickshell` must declare
`X-KDE-Wayland-Interfaces=org_kde_plasma_window_management`, and Quickshell must
then be restarted. Treat that desktop-entry change as an explicit installation
step rather than hiding it inside the QML implementation.

Resolve a human-friendly display name in this order:

1. Read `TasksModel.activeTask`.
2. Read `AbstractTasksModel.AppName` for that model index.
3. Hide the label when the index is invalid or the role is empty.

The lookup must tolerate `activeToplevel === null`, an empty `appId`, and a
desktop entry with an empty name. The component should be hidden when no useful
name is available and should collapse its implicit width to zero rather than
leaving a gap.

### Presentation

- Text color: `#cdd6f4`.
- Font size: 14 pixels.
- Font weight: bold, consistent with the clock.
- Height: inherit the left-controls row height.
- Horizontal padding: 8 pixels on each side.
- Maximum content width: approximately 240 pixels.
- Long application names: `Text.ElideRight`.
- Background: transparent.
- No hover state, pressed pill, popup state, icon, or click handler yet.

The stable component name should remain `AppMenu` even though it initially only
shows an application name. Later milestones will replace or extend its content
without changing the bar's composition API.

### Milestone 1 acceptance checks

- Focusing Dolphin shows `Dolphin`, not its current folder or window title.
- Focusing Konsole shows the desktop-entry name rather than a shell command.
- Switching between applications updates the label without polling.
- Closing the active window selects the next active application's name.
- With no normal active toplevel, the component disappears without leaving
  spacing or binding errors.
- A long application name is elided and does not overlap the center clock.
- Every connected screen shows the same label.
- The required validation command reports `Configuration Loaded` with no QML
  errors.

## Milestone 2: native bridge feasibility spike

Before building menus, make the integration boundary explicit and validate it
with the smallest possible native prototype.

### Preferred approach: local QML plugin

Build a small Qt 6 QML plugin that is imported by the Quickshell configuration.
The plugin should link only what the feature requires:

- Qt Core, Quick, Widgets, and DBus
- KF6 WindowSystem and I18n as needed
- Plasma Workspace's `PW::LibTaskManager`
- `dbusmenuqt`

The spike succeeds when Quickshell can load the local plugin and instantiate a
trivial exported object without startup warnings. Keep build products out of
version control and document the build/install command required after cloning
the dotfiles.

### Fallback approach: companion process

If loading an out-of-tree QML plugin proves brittle across Quickshell or Plasma
updates, use a small long-running Qt helper launched through `Quickshell.Io`
`Process`. Exchange line-delimited JSON over stdin/stdout:

- helper to QML: availability and top-level menu labels
- QML to helper: open, switch, close, and trigger commands with screen
  coordinates

The helper may own and display native `QMenu` instances. This costs more IPC
code but isolates Plasma ABI dependencies from the Quickshell process.

### Decision gate

Record the outcome in this document before proceeding. Prefer the plugin only
if it:

- loads reliably from the live configuration path;
- does not require modifying system QML directories;
- survives Quickshell live reload cleanly;
- can be rebuilt against normal Arch/CachyOS package updates with a documented
  command.

## Milestone 3: active menu discovery

Implement the native model without opening menus yet.

### Responsibilities

- Own `TaskManager::TasksModel` and follow `activeTaskChanged`.
- Re-evaluate when menu-related task roles, activities, desktops, task count,
  or screen geometry change.
- Read `ApplicationMenuServiceName` and `ApplicationMenuObjectPath` for the
  active task.
- Watch the exporting D-Bus service and clear the model if it disappears.
- Expose at least:
  - `menuAvailable`
  - `applicationName` if it improves upon milestone 1 resolution
  - a model of top-level labels
- Retain the milestone 1 application-name fallback when the active application
  exports no global menu.

### Global-menu registration

The bridge must acquire `org.kde.kappmenuview` on the session bus while it is
running. It must release the name on clean shutdown. Handle registration
failure explicitly, because the Plasma applet may still own the name during
development.

Do not remove the Plasma fallback panel as part of this work. For testing menu
registration, temporarily disabling only the Plasma global-menu applet may be
necessary, but that is a manual user action outside this repository.

### Acceptance checks

- The registrar appears when the bridge owns `org.kde.kappmenuview`.
- KDE applications that export menus produce top-level labels such as `File`,
  `Edit`, and `Help`.
- Applications without DBusMenu support continue to show only the application
  name.
- Switching focus cannot leave stale actions from the previous application.
- If an exporting application exits, its menu disappears cleanly.

## Milestone 4: render top-level menu entries

Replace the passive application-name-only content when `menuAvailable` is true:

- Keep the application name at the start as a stable identity label, unless a
  later visual review finds that redundant.
- Render visible top-level actions in source order.
- Preserve action text and enabled/visible state.
- Remove mnemonic markers from normal display while retaining enough metadata
  to add Alt-key mnemonic behavior later.
- Elide or collapse gracefully when the combined menu is wider than the space
  between the left controls and centered clock.

Each control must have a bar-height hit target. Hover surfaces use `#313244`.
The selected/open control uses an inset `#585b70` pill, with radius equal to
half the pill height. The visible surface must not touch the screen edge.

At this stage, clicking an entry may log or expose the selected action index;
menu display is delivered in milestone 5.

## Milestone 5: open and operate menus

Use `DBusMenuImporter` to maintain the imported menu tree and open the selected
top-level action's native `QMenu` below its QML control.

### Required behavior

- Open on pointer press, matching the Plasma applet.
- Position below the selected top-bar item in global coordinates.
- Clamp the menu to the available screen geometry.
- Keep the selected bar item in its open-state pill until the menu closes.
- Close on Escape or an outside click.
- When a menu is open, moving over another top-level entry switches to that
  menu without requiring another click.
- Preserve nested submenus, separators, icons, enabled state, checkboxes,
  radio items, and action activation.
- Respond to live DBusMenu layout/property updates.
- Clear selection reliably when the native menu hides or its source service
  vanishes.
- Ensure interaction with the menu does not cause the active-task model to
  switch to the Quickshell bar or menu window.

If the native bridge presents a `QMenu`, keep popup lifecycle in the bridge and
expose only state and commands to QML. Do not duplicate the complete menu tree
in custom `PopupWindow` delegates unless native `QMenu` proves unusable.

## Milestone 6: keyboard, search, and multi-monitor polish

Add parity features after pointer interaction is stable:

- Left/Right switches between top-level menus.
- Up/Down and Enter follow native menu behavior.
- Escape closes the menu and clears the selected item.
- Alt mnemonic display and activation, if Quickshell/KWin can expose the key
  state reliably.
- Optional searchable action menu, based on the upstream Wayland-only search
  implementation.
- Decide whether to retain the default all-screens behavior or filter menus by
  the screen containing the active task.
- Confirm correct positioning with mixed scale factors and monitors arranged
  above or to the left of the primary screen.

## Test matrix

Exercise each applicable milestone with:

- KDE/Qt applications: Dolphin, Konsole, Kate, System Settings.
- GTK application with appmenu support available.
- An application known not to export a global menu.
- A window with a changing title to confirm that application name and window
  title are not confused.
- Rapid focus switching and application exit.
- Minimized, fullscreen, and transient/dialog windows.
- One monitor and multiple monitors, including mixed scaling when available.
- Quickshell live reload while an application menu is open.
- Plasma appmenu present, absent, and competing for `org.kde.kappmenuview`.

For native code, add focused tests for model reset, service disappearance,
empty menus, action changes, and coordinate clamping where practical.

## Known risks

- **Application coverage:** only applications exporting DBusMenu can provide a
  global menu. Some GTK applications require `appmenu-gtk-module`; Electron and
  other native-Wayland applications may export nothing.
- **Private Plasma API:** `PW::LibTaskManager` is a Plasma Workspace library and
  may change ABI during upgrades. Keep the bridge small and easy to rebuild.
- **Plugin loading:** a native QML plugin runs inside Quickshell, so an ABI error
  can prevent the shell from loading. The companion-process fallback reduces
  this failure domain.
- **D-Bus ownership:** the Plasma global-menu applet and Quickshell version
  cannot both be the active `org.kde.kappmenuview` owner without deliberate
  queuing/replacement behavior.
- **Focus and grabs:** native `QMenu` interaction on Wayland has edge cases
  around focus, transient parents, mouse grabs, and hover-switching. Port the
  upstream workarounds deliberately rather than simplifying them away.
- **Licensing:** code adapted from the KDE applet must retain its SPDX and
  copyright notices and remain compatible with its GPL licensing.

## Definition of done

The feature is complete when the bar reliably identifies the active
application, shows its exported top-level menu when available, opens and
operates native menus with mouse and keyboard, behaves correctly across
monitors and live reloads, and degrades to the application-name label for
unsupported applications without affecting the rest of the bar.
