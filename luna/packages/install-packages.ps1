param(
    [Parameter(Position=0)]
    [ValidateSet("winget", "choco", "scoop", "powershell", "all")]
    [string]$Method = "all"
)

# Get the directory where this script is located
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$JsonFile = Join-Path $scriptPath "packages.json"

# Check if packages.json exists
if (-not (Test-Path $JsonFile)) {
    Write-Error "packages.json not found in script directory: $scriptPath"
    exit 1
}

# Read package list
$packagesData = Get-Content $JsonFile | ConvertFrom-Json

# Check if running as administrator for Chocolatey packages
if (($Method -eq "all" -or $Method -eq "choco") -and $packagesData.choco.Count -gt 0) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Chocolatey packages require administrator privileges. Please run this script as Administrator."
        Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
        exit 1
    }
}

# Ensure Chocolatey is installed if needed
if (($Method -eq "all" -or $Method -eq "choco") -and $packagesData.choco.Count -gt 0) {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found...."
        Write-Host "Run: Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
        exit 1
    }
}

# Ensure Scoop is installed if needed
if (($Method -eq "all" -or $Method -eq "scoop") -and $packagesData.scoop.Count -gt 0) {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found...."
        Write-Host "Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
        exit 1
    }
}

$jobs = @()

# Process winget packages (first)
if (($Method -eq "all" -or $Method -eq "winget") -and $packagesData.winget) {
    foreach ($packageId in $packagesData.winget) {
        if ($packageId -and $packageId.Trim() -ne "") {
            Write-Host "Queuing winget installation: $packageId"
            $job = Start-Job -ScriptBlock {
                param($packageId)
                try {
                    $result = winget install --id $packageId --accept-package-agreements --accept-source-agreements 2>&1
                    $output = $result -join "`n"
                    
                    # Check for specific success/info conditions
                    $isAlreadyInstalled = $output -match "No available upgrade found|No newer version was found|already installed"
                    $isSuccess = ($LASTEXITCODE -eq 0) -or $isAlreadyInstalled
                    
                    return @{
                        Success = $isSuccess
                        PackageId = $packageId
                        Method = "winget"
                        Output = $output
                        ExitCode = $LASTEXITCODE
                        IsAlreadyInstalled = $isAlreadyInstalled
                    }
                }
                catch {
                    return @{
                        Success = $false
                        PackageId = $packageId
                        Method = "winget"
                        Output = $_.Exception.Message
                        ExitCode = -1
                        IsAlreadyInstalled = $false
                    }
                }
            } -ArgumentList $packageId
            $jobs += $job
        }
    }
}

# Wait for winget jobs to complete before starting choco
if ($jobs.Count -gt 0) {
    Write-Host "`nWaiting for winget installations to complete..." -ForegroundColor Cyan
    Wait-Job -Job $jobs | Out-Null
}

# Process choco packages (second)
if (($Method -eq "all" -or $Method -eq "choco") -and $packagesData.choco) {
    foreach ($packageId in $packagesData.choco) {
        if ($packageId -and $packageId.Trim() -ne "") {
            Write-Host "Queuing choco installation: $packageId"
            $job = Start-Job -ScriptBlock {
                param($packageId)
                try {
                    $result = choco install $packageId -y 2>&1
                    $output = $result -join "`n"
                    
                    # Check for specific success/info conditions
                    $isAlreadyInstalled = $output -match "already installed|same version of .* is already installed"
                    $isSuccess = ($LASTEXITCODE -eq 0) -or $isAlreadyInstalled
                    
                    return @{
                        Success = $isSuccess
                        PackageId = $packageId
                        Method = "choco"
                        Output = $output
                        ExitCode = $LASTEXITCODE
                        IsAlreadyInstalled = $isAlreadyInstalled
                    }
                }
                catch {
                    return @{
                        Success = $false
                        PackageId = $packageId
                        Method = "choco"
                        Output = $_.Exception.Message
                        ExitCode = -1
                        IsAlreadyInstalled = $false
                    }
                }
            } -ArgumentList $packageId
            $jobs += $job
        }
    }
}

# Wait for choco jobs to complete before starting scoop
if ($jobs.Count -gt 0) {
    Write-Host "`nWaiting for choco installations to complete..." -ForegroundColor Cyan
    Wait-Job -Job $jobs | Out-Null
}

# Process scoop packages (third)
if (($Method -eq "all" -or $Method -eq "scoop") -and $packagesData.scoop) {
    foreach ($packageId in $packagesData.scoop) {
        if ($packageId -and $packageId.Trim() -ne "") {
            Write-Host "Queuing scoop installation: $packageId"
            $job = Start-Job -ScriptBlock {
                param($packageId)
                try {
                    $result = scoop install $packageId 2>&1
                    $output = $result -join "`n"
                    
                    # Check for specific success/info conditions
                    $isAlreadyInstalled = $output -match "is already installed"
                    $isSuccess = ($LASTEXITCODE -eq 0) -or $isAlreadyInstalled
                    
                    return @{
                        Success = $isSuccess
                        PackageId = $packageId
                        Method = "scoop"
                        Output = $output
                        ExitCode = $LASTEXITCODE
                        IsAlreadyInstalled = $isAlreadyInstalled
                    }
                }
                catch {
                    return @{
                        Success = $false
                        PackageId = $packageId
                        Method = "scoop"
                        Output = $_.Exception.Message
                        ExitCode = -1
                        IsAlreadyInstalled = $false
                    }
                }
            } -ArgumentList $packageId
            $jobs += $job
        }
    }
}

# Wait for scoop jobs to complete before starting PowerShell scripts
if ($jobs.Count -gt 0) {
    Write-Host "`nWaiting for scoop installations to complete..." -ForegroundColor Cyan
    Wait-Job -Job $jobs | Out-Null
}

# Process PowerShell scripts (last)
if (($Method -eq "all" -or $Method -eq "powershell") -and $packagesData.powershell) {
    foreach ($psScript in $packagesData.powershell) {
        if ($psScript.script) {
            Write-Host "Queuing PowerShell script execution: $($psScript.script)"
            $job = Start-Job -ScriptBlock {
                param($script, $policy)
                try {
                    # Set execution policy if specified
                    if ($policy) {
                        Set-ExecutionPolicy -ExecutionPolicy $policy -Scope Process -Force
                    }
                    
                    # Execute the PowerShell script
                    $result = Invoke-Expression $script 2>&1
                    $output = $result -join "`n"
                    
                    return @{
                        Success = $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
                        PackageId = $script.Substring(0, [Math]::Min(50, $script.Length))
                        Method = "powershell"
                        Output = $output
                        ExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
                        IsAlreadyInstalled = $false
                    }
                }
                catch {
                    return @{
                        Success = $false
                        PackageId = $script.Substring(0, [Math]::Min(50, $script.Length))
                        Method = "powershell"
                        Output = $_.Exception.Message
                        ExitCode = -1
                        IsAlreadyInstalled = $false
                    }
                }
            } -ArgumentList $psScript.script, $psScript.executionPolicy
            $jobs += $job
        }
    }
}

# Monitor jobs in real-time and display results as they complete
if ($jobs.Count -gt 0) {
    $completedJobs = @()
    $successCount = 0
    $failureCount = 0
    $alreadyInstalledCount = 0
    
    # Poll for completed jobs
    while ($completedJobs.Count -lt $jobs.Count) {
        foreach ($job in $jobs) {
            if ($job.State -eq "Completed" -and $job -notin $completedJobs) {
                $result = Receive-Job -Job $job
                $completedJobs += $job
                
                if ($result.Success) {
                    if ($result.IsAlreadyInstalled) {
                        # Write-Host "ℹ️  ALREADY INSTALLED: $($result.Method) - $($result.PackageId)" -ForegroundColor Cyan
                        $alreadyInstalledCount++
                    } else {
                        Write-Host "✅ SUCCESS: $($result.Method) - $($result.PackageId)" -ForegroundColor Green
                        $successCount++
                    }
                } else {
                    Write-Host "❌ FAILED:  $($result.Method) - $($result.PackageId)" -ForegroundColor Red
                    # Show only the last few lines of error output to avoid spam
                    $errorLines = $result.Output -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 3
                    foreach ($line in $errorLines) {
                        Write-Host "   $line" -ForegroundColor Yellow
                    }
                    $failureCount++
                }
                
                # Clean up the completed job
                Remove-Job -Job $job
            }
        }
        
        # Small delay to avoid excessive CPU usage
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "✅ Newly Installed: $successCount" -ForegroundColor Green
    Write-Host "ℹ️ Already Installed: $alreadyInstalledCount" -ForegroundColor Cyan  
    if ($failureCount -gt 0) {
        Write-Host "❌ Failed: $failureCount" -ForegroundColor Red
    }
    Write-Host "📦 Total Processed: $($successCount + $alreadyInstalledCount + $failureCount)"
    exit 0
} else {
    Write-Host "No packages to install."
    exit 0
}
