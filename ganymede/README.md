# Ganymede

Bazzite Linux desktop PC

## Scripts

Set up the Homebrew (or system) zsh, install this repository's `~/.zshrc`, and
create the default Konsole `Zsh` profile:

```sh
./scripts/setup-zsh.sh
```

The script locates Homebrew's zsh first, then a system zsh; set `ZSH_PATH` to
an absolute executable path to override that choice. It backs up a differing
existing `~/.zshrc` and `konsolerc` before changing them. The installed shell
configuration is an exact copy of the checked-in `zsh/zshrc` file.

`scripts/toggle-hdr.sh` and `scripts/toggle-vrr.sh` toggle the corresponding
KDE display setting. They require `kscreen-doctor` and `jq`.
When `notify-send` is available (it normally is on Bazzite), they send a desktop
notification after completing successfully.

Pass the output name explicitly, for example:

```sh
./scripts/toggle-hdr.sh DP-1
./scripts/toggle-vrr.sh DP-1
```

Install the helper commands in `~/.local/bin` with:

```sh
./scripts/install.sh
```

This also installs a **Reboot into Windows** application launcher with the
Windows 11 logo from the prior NixOS setup. It asks for confirmation, sets the
Windows UEFI entry for the next boot, and reboots. When `efibootmgr` is
available, the installer adds a narrowly scoped `sudoers` rule that permits
only reading the boot entries and `efibootmgr --bootnext …`, with no password.
The installer may ask for your password once to add that system rule;
subsequent `boot-windows` runs do not prompt for one.

Install the 1Password desktop app and CLI by layering their RPM packages with
rpm-ostree:

```sh
./scripts/install-1password.sh
```

The script adds 1Password's Stable Channel repository and signing key, then
installs `1password` and `1password-cli`. It also assigns `Ctrl+Shift+Space`
to open 1Password Quick Access. Restart after rpm-ostree completes to use the
newly deployed image and shortcut.

Alternatively, set `PRIMARY_MONITOR`. With no configured output, the scripts
use KDE's primary display, or the only enabled display. With multiple enabled
displays and no primary, they safely print the available output names instead
of choosing one arbitrarily. Run `kscreen-doctor --json | jq -r
'.outputs[].name'` to list outputs yourself.
