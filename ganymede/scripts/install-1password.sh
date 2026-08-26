#!/usr/bin/env bash
# Install 1Password and its CLI on rpm-ostree-based systems such as Bazzite.

set -euo pipefail

readonly key_url='https://downloads.1password.com/linux/keys/1password.asc'
readonly key_path='/etc/pki/rpm-gpg/RPM-GPG-KEY-1password'
readonly repo_path='/etc/yum.repos.d/1password.repo'
readonly shortcut_desktop_file="$HOME/.local/share/applications/1password-quick-access.desktop"

curl --fail --location --silent --show-error "$key_url" \
  | sudo tee "$key_path" >/dev/null

sudo tee "$repo_path" >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-1password
EOF

sudo rpm-ostree install 1password 1password-cli

# Register a Plasma command shortcut for 1Password Quick Access. It is read on
# the next login, which also occurs after the rpm-ostree deployment is rebooted.
install -Dm644 /dev/stdin "$shortcut_desktop_file" <<'EOF'
[Desktop Entry]
Exec=1password --quick-access
Name=1Password
NoDisplay=true
StartupNotify=false
Type=Application
X-KDE-GlobalAccel-CommandShortcut=true
EOF

kwriteconfig6 --file kglobalshortcutsrc \
  --group services \
  --group 1password-quick-access.desktop \
  --key _k_friendly_name '1Password'
kwriteconfig6 --file kglobalshortcutsrc \
  --group services \
  --group 1password-quick-access.desktop \
  --key _launch 'Ctrl+Shift+Space,none,1Password'
