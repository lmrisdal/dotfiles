#!/usr/bin/env bash
# Toggle variable refresh rate (VRR) for a KDE Plasma display.
# Usage: toggle-vrr.sh [monitor-name]

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
  notify-send --app-name="toggle-vrr" "VRR" "$1"
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

vrr_policy=$(jq -r --arg monitor "$monitor" \
  '.outputs[] | select(.name == $monitor) | .vrrPolicy' <<<"$screens")

if [[ -z "$vrr_policy" || "$vrr_policy" == "null" ]]; then
  echo "Error: monitor '$monitor' was not found." >&2
  exit 1
fi

if [[ "$vrr_policy" == 0 ]]; then
  kscreen-doctor "output.$monitor.vrrpolicy.automatic"
  echo "VRR set to automatic on $monitor."
  notify "Set to automatic on $monitor"
else
  kscreen-doctor "output.$monitor.vrrpolicy.never"
  echo "VRR disabled on $monitor."
  notify "Disabled on $monitor"
fi
