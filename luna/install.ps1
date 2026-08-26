#Requires -RunAsAdministrator

# Dotfiles Installation Script
# Installs shell configuration, system tweaks, and packages

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Dotfiles Installation" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot

# Step 1: Setup Shell
Write-Host "[1/3] Setting up PowerShell profile..." -ForegroundColor Magenta
$response = Read-Host "Do you want to setup shell configuration? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    & "$scriptRoot\shell\setup-shell.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Shell setup failed!"
        exit 1
    }
} else {
    Write-Host "Skipped shell setup." -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Run WinUtil Tweaks
Write-Host "[2/3] Running system tweaks with WinUtil..." -ForegroundColor Magenta
$response = Read-Host "Do you want to run WinUtil system tweaks? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    & "$scriptRoot\winutil\run-tweaks.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "WinUtil tweaks encountered an issue, but continuing..."
    }
} else {
    Write-Host "Skipped WinUtil tweaks." -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Install Packages
Write-Host "[3/3] Installing packages..." -ForegroundColor Magenta
$response = Read-Host "Do you want to install packages? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    & "$scriptRoot\packages\install-packages.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Package installation encountered issues, check output above."
    }
} else {
    Write-Host "Skipped package installation." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "======================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "You may need to restart your terminal for changes to take effect." -ForegroundColor Yellow