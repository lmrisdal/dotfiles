#!/usr/bin/env bash
# Toggle HDR and wide color gamut (WCG) for a KDE Plasma display.
# Usage: toggle-hdr.sh [monitor-name]

set -euo pipefail

command -v kscreen-doctor >/dev/null || {
  echo "Error: kscreen-doctor is required." >&2
  exit 1
}
command -v jq >/dev/null || {
  echo "Error: jq is required." >&2
  exit 1
}

notify() {
  command -v notify-send >/dev/null || return 0
  notify-send --app-name="toggle-hdr" "HDR" "$1"
}

screens=$(kscreen-doctor --json)
monitor=${1:-${PRIMARY_MONITOR:-}}

if [[ -z "$monitor" ]]; then
  monitor=$(jq -r '
    [.outputs[] | select(.primary == true and .enabled == true) | .name]
    | if length == 1 then .[0] else empty end
  ' <<<"$screens")
fi

# KScreen does not always report a primary output on Wayland.  A single active
# output is unambiguous, so use it; do not guess when several are active.
if [[ -z "$monitor" ]]; then
  monitor=$(jq -r '
    [.outputs[] | select(.enabled == true) | .name]
    | if length == 1 then .[0] else empty end
  ' <<<"$screens")
fi

if [[ -z "$monitor" || "$monitor" == "null" ]]; then
  echo "Error: no monitor specified and no unambiguous active KDE output found." >&2
  echo "Usage: $0 <monitor-name>" >&2
  echo "Available outputs:" >&2
  jq -r '.outputs[] | "  \(.name) (enabled: \(.enabled))"' <<<"$screens" >&2
  exit 1
fi

hdr_status=$(jq -r --arg monitor "$monitor" \
  '.outputs[] | select(.name == $monitor) | .hdr' <<<"$screens")

if [[ -z "$hdr_status" || "$hdr_status" == "null" ]]; then
  echo "Error: monitor '$monitor' was not found." >&2
  exit 1
fi

case "$hdr_status" in
  false)
    kscreen-doctor "output.$monitor.hdr.enable"
    kscreen-doctor "output.$monitor.wcg.enable"
    echo "HDR enabled on $monitor."
    notify "Enabled on $monitor"
    ;;
  true)
    kscreen-doctor "output.$monitor.hdr.disable"
    kscreen-doctor "output.$monitor.wcg.disable"
    echo "HDR disabled on $monitor."
    notify "Disabled on $monitor"
    ;;
  *)
    echo "Error: unexpected HDR status '$hdr_status' for '$monitor'." >&2
    exit 1
    ;;
esac
