#!/usr/bin/env bash
# Set up zsh, its startup file, and a default Konsole profile on KDE Plasma.

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
zshrc_source="$repo_dir/zsh/zshrc"
zshrc_destination="$HOME/.zshrc"
konsole_dir="${XDG_DATA_HOME:-$HOME/.local/share}/konsole"
konsolerc_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
profile_path="$konsole_dir/Zsh.profile"
konsolerc_path="$konsolerc_dir/konsolerc"

find_zsh() {
  if [[ -n "${ZSH_PATH:-}" && -x "$ZSH_PATH" ]]; then
    printf '%s\n' "$ZSH_PATH"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    local brew_zsh
    brew_zsh="$(brew --prefix zsh 2>/dev/null)/bin/zsh"
    if [[ -x "$brew_zsh" ]]; then
      printf '%s\n' "$brew_zsh"
      return
    fi
  fi

  if command -v zsh >/dev/null 2>&1; then
    command -v zsh
    return
  fi

  return 1
}

zsh_path=$(find_zsh) || {
  echo "Error: zsh was not found. Install it first, or set ZSH_PATH to its absolute path." >&2
  exit 1
}

if [[ -e "$zshrc_destination" && ! -L "$zshrc_destination" ]] \
  && ! cmp -s "$zshrc_source" "$zshrc_destination"; then
  backup_path="$zshrc_destination.backup.$(date +%Y%m%d%H%M%S)"
  cp -p "$zshrc_destination" "$backup_path"
  echo "Backed up existing ~/.zshrc to $backup_path"
fi

install -Dm644 "$zshrc_source" "$zshrc_destination"

mkdir -p "$konsole_dir" "$konsolerc_dir"
printf '[General]\nCommand=%s\nName=Zsh\nParent=FALLBACK/\n' "$zsh_path" >"$profile_path"

if [[ -f "$konsolerc_path" ]] && ! grep -q '^DefaultProfile=Zsh\.profile$' "$konsolerc_path"; then
  cp -p "$konsolerc_path" "$konsolerc_path.backup.$(date +%Y%m%d%H%M%S)"
fi

konsole_tmp=$(mktemp "$konsolerc_path.tmp.XXXXXX")
awk '
  BEGIN { section = ""; desktop_entry = 0; default_written = 0 }
  /^\[/ {
    if (section == "[Desktop Entry]" && !default_written) {
      print "DefaultProfile=Zsh.profile"
      default_written = 1
    }
    section = $0
    if (section == "[Desktop Entry]") desktop_entry = 1
    print
    next
  }
  section == "[Desktop Entry]" && /^DefaultProfile=/ {
    if (!default_written) print "DefaultProfile=Zsh.profile"
    default_written = 1
    next
  }
  { print }
  END {
    if (!desktop_entry) {
      print ""
      print "[Desktop Entry]"
      print "DefaultProfile=Zsh.profile"
    } else if (section == "[Desktop Entry]" && !default_written) {
      print "DefaultProfile=Zsh.profile"
    }
  }
' "$konsolerc_path" 2>/dev/null >"$konsole_tmp" || {
  rm -f "$konsole_tmp"
  exit 1
}
mv "$konsole_tmp" "$konsolerc_path"

echo "Installed ~/.zshrc and made the Zsh Konsole profile the default."
echo "Open a new Konsole window to use it."
