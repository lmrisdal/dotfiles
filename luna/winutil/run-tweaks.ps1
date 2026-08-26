param(
    [switch]$Force
)

# Chris Titus Tech WinUtil with configuration
Write-Host "Running Chris Titus Tech WinUtil with configuration..." -ForegroundColor Cyan

$registryPath = "HKCU:\Software\Dotfiles"
$registryKey = "WinUtilCompleted"

# Check if already run (unless -Force is specified)
if (-not $Force) {
    try {
        $completed = Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction Stop
        if ($completed.$registryKey -eq 1) {
            Write-Host "WinUtil tweaks have already been applied. Skipping..." -ForegroundColor Yellow
            Write-Host "To re-run, use: .\run-tweaks.ps1 -Force" -ForegroundColor Gray
            Write-Host "Or delete registry key: $registryPath\$registryKey" -ForegroundColor Gray
            exit 0
        }
    }
    catch {
        # Registry key doesn't exist, continue with installation
    }
} else {
    Write-Host "Force flag detected, running WinUtil..." -ForegroundColor Yellow
}

try {
    # Get the directory where this script is located
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $configPath = Join-Path $scriptPath "winutil.json"
    
    # Check if config file exists
    if (-not (Test-Path $configPath)) {
        Write-Warning "winutil.json not found in script directory: $scriptPath"
        Write-Host "Running WinUtil without configuration file..."
        Invoke-Expression "& { $(irm https://christitus.com/win) }"
    } else {
        Write-Host "Using configuration file: $configPath"
        Invoke-Expression "& { $(irm https://christitus.com/win) } -Config `"$configPath`" -Run"
    }
    
    # Mark as completed in registry
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $registryPath -Name $registryKey -Value 1 -Type DWord
    
    Write-Host "WinUtil execution completed." -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to run WinUtil: $($_.Exception.Message)"
    Write-Host "You can try running it manually with:"
    Write-Host "iex `"& { `$(irm https://christitus.com/win) }`""
    exit 1
}