#!/usr/bin/env bash
# Install the Ganymede helper scripts into ~/.local/bin.

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"

install -Dm755 "$script_dir/toggle-hdr.sh" "$bin_dir/toggle-hdr"
install -Dm755 "$script_dir/toggle-vrr.sh" "$bin_dir/toggle-vrr"
install -Dm755 "$script_dir/toggle-night-light.sh" "$bin_dir/toggle-night-light"
install -Dm755 "$script_dir/boot-windows.sh" "$bin_dir/boot-windows"
install -Dm644 "$project_dir/desktop/boot-windows.desktop" "$data_dir/applications/boot-windows.desktop"
install -Dm644 "$project_dir/icons/boot-windows.png" "$data_dir/icons/hicolor/256x256/apps/boot-windows.png"

efibootmgr_path=$(command -v efibootmgr || true)
if [ -n "$efibootmgr_path" ]; then
  sudoers_file=$(mktemp)
  trap 'rm -f "$sudoers_file"' EXIT

  printf '%s ALL=(root) NOPASSWD: %s, %s --bootnext *\n' "$(id -un)" "$efibootmgr_path" "$efibootmgr_path" >"$sudoers_file"
  visudo -cf "$sudoers_file"
  sudo install -Dm440 "$sudoers_file" /etc/sudoers.d/boot-windows
  echo "Configured passwordless Windows boot selection"
else
  echo "Note: efibootmgr is not installed, so passwordless Windows boot selection was not configured."
fi

echo "Installed programs to $bin_dir"
echo "Installed the Reboot into Windows launcher"

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    echo "Note: $bin_dir is not currently on PATH. Add it to your shell configuration, then open a new terminal."
    ;;
esac
