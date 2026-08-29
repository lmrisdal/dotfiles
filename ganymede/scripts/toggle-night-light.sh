#!/usr/bin/env bash
# Toggle KDE Plasma Night Light.
# Usage: toggle-night-light.sh

set -euo pipefail

command -v kreadconfig6 >/dev/null || {
  echo "Error: kreadconfig6 is required." >&2
  exit 1
}
command -v kwriteconfig6 >/dev/null || {
  echo "Error: kwriteconfig6 is required." >&2
  exit 1
}
command -v qdbus6 >/dev/null || {
  echo "Error: qdbus6 is required." >&2
  exit 1
}

notify() {
  command -v notify-send >/dev/null || return 0
  notify-send --app-name="toggle-night-light" "Night Light" "$1"
}

toggle_live_night_light() {
  qdbus6 org.kde.kglobalaccel /component/kwin \
    org.kde.kglobalaccel.Component.invokeShortcut "Toggle Night Color"
}

# Plasma represents the UI's "Sunrise and sunset" choice as Active=true and
# Mode=1 (DarkLight). "Always off" is simply Active=false.
active=$(kreadconfig6 --file kwinrc --group NightColor --key Active --default false)
inhibited_by_helper=$(kreadconfig6 --file kwinrc --group NightColor \
  --key ToggleNightLightInhibited --default false)

case "$active" in
  true)
    kwriteconfig6 --file kwinrc --group NightColor --key Active false
    # Updating kwinrc alone does not reliably refresh KWin's running Night
    # Light plugin. Its built-in action applies the change immediately.
    toggle_live_night_light
    kwriteconfig6 --file kwinrc --group NightColor --key ToggleNightLightInhibited true
    status="Disabled"
    ;;
  false)
    kwriteconfig6 --file kwinrc --group NightColor --key Active true
    kwriteconfig6 --file kwinrc --group NightColor --key Mode 1
    # Only resume a suspension that this helper created; another application
    # may have independently inhibited Night Light.
    case "$inhibited_by_helper" in
      true)
        toggle_live_night_light
        ;;
      false) ;;
      *)
        echo "Error: unexpected helper inhibition status '$inhibited_by_helper' in kwinrc." >&2
        exit 1
        ;;
    esac
    kwriteconfig6 --file kwinrc --group NightColor --key ToggleNightLightInhibited false
    status="Set to sunrise and sunset"
    ;;
  *)
    echo "Error: unexpected Night Light status '$active' in kwinrc." >&2
    exit 1
    ;;
esac

# Reload KWin's configuration for the persistent setting; the shortcut above
# is what applies the visible color change immediately.
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure

echo "Night Light $status."
notify "$status"
