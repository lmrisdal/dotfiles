# Vendored DBusMenu importer

These sources come from `libdbusmenuqt` in KDE Plasma Workspace 6.7.4, tag
`v6.7.4` (commit `fd05ec29e599948a120eb7485248d4a86a7d78f1`). They retain their upstream SPDX
headers and are distributed under the indicated LGPL licenses.

`debug.h` and `debug.cpp` replace the logging-category files normally generated
by Plasma Workspace's CMake build. They use the same
`org.kde.libdbusmenuqt` category and are licensed LGPL-2.0-or-later.

When updating Plasma, compare this directory with
`libdbusmenuqt` in the matching Plasma Workspace source tree and rebuild the
helper before restarting Quickshell.
