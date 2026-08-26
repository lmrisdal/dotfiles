# Shell Configuration Setup
Write-Host "Setting up shell configuration..." -ForegroundColor Cyan

# Define symlink mappings (source = where the symlink should be, target = your dotfiles location)
$mappings = @(
    @{
        source = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        target = "$PSScriptRoot\Profile.ps1"
        description = "PowerShell profile"
    },
    @{
        source = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        target = "$PSScriptRoot\WindowsTerminal.json"
        description = "Windows Terminal settings"
    }
)

$successCount = 0
$skipCount = 0
$failCount = 0

foreach ($mapping in $mappings) {
    Write-Host "`nProcessing: $($mapping.description)" -ForegroundColor Cyan
    
    $sourcePath = $mapping.source
    $targetPath = $mapping.target
    
    # Check if target file exists in dotfiles
    if (-not (Test-Path $targetPath)) {
        Write-Host "⚠️  Target file not found in dotfiles: $targetPath" -ForegroundColor Yellow
        Write-Host "   Skipping $($mapping.description)..." -ForegroundColor Yellow
        $skipCount++
        continue
    }
    
    # Create parent directory if it doesn't exist
    $sourceDir = Split-Path -Parent $sourcePath
    if (-not (Test-Path $sourceDir)) {
        try {
            New-Item -ItemType Directory -Path $sourceDir -Force -ErrorAction Stop | Out-Null
            Write-Host "   Created directory: $sourceDir" -ForegroundColor Gray
        }
        catch {
            Write-Host "❌ Failed to create directory: $sourceDir" -ForegroundColor Red
            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
            $failCount++
            continue
        }
    }
    
    # Check if source already exists
    if (Test-Path $sourcePath) {
        $item = Get-Item $sourcePath -ErrorAction SilentlyContinue
        
        # If it's already a symlink pointing to the correct target, skip
        if ($item.LinkType -eq "SymbolicLink" -and $item.Target -eq $targetPath) {
            Write-Host "✓ Already symlinked correctly" -ForegroundColor Green
            $successCount++
            continue
        }
        
        # If it's not a symlink or points elsewhere, remove it
        if (-not $item.LinkType) {
            Write-Host "   Removing existing non-symlinked file..." -ForegroundColor Yellow
        } else {
            Write-Host "   Removing existing symlink (points to: $($item.Target))..." -ForegroundColor Yellow
        }
        
        try {
            Remove-Item $sourcePath -Force -ErrorAction Stop
        }
        catch {
            Write-Host "❌ Failed to remove existing file" -ForegroundColor Red
            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
            $failCount++
            continue
        }
    }
    
    # Create the symlink
    try {
        New-Item -ItemType SymbolicLink -Path $sourcePath -Target $targetPath -Force -ErrorAction Stop | Out-Null
        Write-Host "✓ Symlinked successfully" -ForegroundColor Green
        Write-Host "   $sourcePath -> $targetPath" -ForegroundColor Gray
        $successCount++
    }
    catch {
        Write-Host "❌ Failed to create symlink" -ForegroundColor Red
        Write-Host "   Make sure you're running as Administrator" -ForegroundColor Yellow
        Write-Host "   Source: $sourcePath" -ForegroundColor Yellow
        Write-Host "   Target: $targetPath" -ForegroundColor Yellow
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $failCount++
    }
}

# Summary
Write-Host "`n" -NoNewline
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Successfully symlinked: $successCount" -ForegroundColor Green
if ($skipCount -gt 0) {
    Write-Host "⚠️  Skipped: $skipCount" -ForegroundColor Yellow
}
if ($failCount -gt 0) {
    Write-Host "❌ Failed: $failCount" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    exit 1
}
Write-Host "========================================" -ForegroundColor Cyan
exit 0
