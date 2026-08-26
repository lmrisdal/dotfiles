# Windows Dotfiles

Personal Windows configuration and setup automation.

## 🚀 Quick Start

**Run as Administrator:**

```powershell
.\install.ps1
```

This will:

1. Symlink PowerShell profile from this repo to `~\Documents\PowerShell\`
2. Apply system tweaks using Chris Titus Tech's WinUtil
3. Install all packages defined in `packages/packages.json`

## 📁 Structure

```
dotfiles-windows/
├── install.ps1              # Main installation script (run as admin)
├── shell/
│   ├── setup-shell.ps1      # PowerShell profile setup
│   └── Microsoft.PowerShell_profile.ps1
├── packages/
│   ├── install-packages.ps1 # Package installation script
│   └── packages.json        # Package definitions
└── winutil/
    ├── run-tweaks.ps1       # System tweaks runner
    └── winutil.json         # WinUtil configuration
```

## 🔧 Manual Setup

If you want to run individual components:

### Shell Setup

```powershell
# Run as Administrator
.\shell\setup-shell.ps1
```

### System Tweaks

```powershell
.\winutil\run-tweaks.ps1
```

### Package Installation

```powershell
# Install all packages
.\packages\install-packages.ps1

# Or specify method: winget, choco, powershell, or all
.\packages\install-packages.ps1 -Method winget
```

## ⚠️ Prerequisites

- **Administrator privileges** (required for symlinks)
- **Chocolatey** - [Install Guide](https://chocolatey.org/install)
- **Scoop** - [Install Guide](https://scoop.sh/)
- **Winget** (included with Windows 11)

## 📝 Notes

- The PowerShell profile is symlinked, so edits in either location affect the same file
- Package installation runs in parallel for faster setup
- WinUtil configuration is stored in `winutil/winutil.json`
