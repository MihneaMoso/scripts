# installtlauncher.ps1
# Script made by @MihneaMoso
# Copyright © 2025 Mihnea Moso

Set-StrictMode -Version Latest
$VerbosePreference = "Continue"

# 0.  Self-elevate execution-policy for THIS process only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"

Write-Verbose "Starting script..."

function Get-File($url, $out) {
    Write-Host "=> Downloading $url ..." -ForegroundColor Cyan
    & curl.exe -L -o $out -# $url
    if ($LASTEXITCODE) { throw "curl failed" }
}


$username = $Env:UserName
$downloads = "C:\Users\$username\Downloads\"
# curl.exe https://mmoso.vercel.app/icons/favicon.ico -o favicon.ico
$tlauncher_url = "https://dl2.tlauncher.org/f.php?f=files%2FTLauncher-Installer-1.9.3.exe"
$tlauncher_path = "$downloads\tlauncher_installer.exe"
Get-File $tlauncher_url $tlauncher_path
C:\Windows\System32\cmd.exe /min /C "set __COMPAT_LAYER=RUNASINVOKER && start `"`" `"$tlauncher_path`""


Write-Verbose "Ending script."
