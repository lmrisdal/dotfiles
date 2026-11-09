#!/usr/bin/env bash

set -euo pipefail

confirm_reboot() {
  if command -v yad >/dev/null 2>&1; then
    yad --title="Reboot into Windows" --button=Yes:0 --button=No:1 \
      --text="Do you want to reboot into Windows?" --width=300 --center
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --title "Reboot into Windows" --yesno "Do you want to reboot into Windows?"
  elif command -v zenity >/dev/null 2>&1; then
    zenity --question --title="Reboot into Windows" \
      --text="Do you want to reboot into Windows?"
  else
    printf 'Do you want to reboot into Windows? [y/N] '
    read -r answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
  fi
}

show_error() {
  local message=$1

  if command -v yad >/dev/null 2>&1; then
    yad --title="Reboot into Windows" --text="$message" --button=OK
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --title "Reboot into Windows" --error "$message"
  elif command -v zenity >/dev/null 2>&1; then
    zenity --error --title="Reboot into Windows" --text="$message"
  else
    printf '%s\n' "$message" >&2
  fi
}

confirm_reboot || exit 0

efibootmgr_path=$(command -v efibootmgr || true)

if [ -z "$efibootmgr_path" ]; then
  show_error "efibootmgr is not installed."
  exit 1
fi

if ! boot_entries=$(sudo -n "$efibootmgr_path"); then
  show_error "Passwordless Windows boot selection is not configured. Run scripts/install.sh first."
  exit 1
fi

boot_id=$(awk '/Windows/ {print substr($1, 5, 4); exit}' <<<"$boot_entries")

if [ -z "$boot_id" ]; then
  show_error "Windows boot entry not found."
  exit 1
fi

if ! sudo -n "$efibootmgr_path" --bootnext "$boot_id"; then
  show_error "Failed to set Windows as the next boot entry."
  exit 1
fi

systemctl reboot || show_error "Failed to reboot the system."
