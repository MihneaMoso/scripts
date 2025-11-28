# XMRig Automated Uninstaller
# IMPORTANT: This script will forcibly stop xmrig.exe and delete the C:\XMRig folder.

# --- Self-Elevation / Admin Check ---
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "Not running as Administrator. Attempting to elevate..." -ForegroundColor Yellow
    
    # Check if we are running from a file or memory
    if ($PSCommandPath) {
        # Running from a file - we can restart easily
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } else {
        # Running from memory (IEX) - we cannot easily restart
        Write-Error "Cannot auto-elevate when running via IEX (memory). Please run your PowerShell terminal as Administrator and try again."
        exit 1
    }
}

Write-Host "Running with Administrator privileges." -ForegroundColor Green

# --- Configuration ---
$InstallDir = "C:\XMRig"

# --- Stop Process ---
Write-Host "Checking for running XMRig processes..." -ForegroundColor Cyan
$Process = Get-Process -Name "xmrig" -ErrorAction SilentlyContinue

if ($Process) {
    Write-Host "Found running XMRig process. Stopping..." -ForegroundColor Yellow
    Stop-Process -Name "xmrig" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2 # Wait for file handles to release
    Write-Host "Process stopped." -ForegroundColor Green
} else {
    Write-Host "XMRig is not currently running." -ForegroundColor Gray
}

# --- Remove Files ---
if (Test-Path -Path $InstallDir) {
    Write-Host "Removing installation directory: $InstallDir" -ForegroundColor Cyan
    try {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction Stop
        Write-Host "Successfully removed $InstallDir" -ForegroundColor Green
    } catch {
        Write-Error "Could not remove directory. It might be open in another program or blocked by Antivirus."
        Write-Error $_
    }
} else {
    Write-Warning "Directory $InstallDir does not exist. XMRig might already be uninstalled."
}

Write-Host "---------------------------------------------------"
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "---------------------------------------------------" 