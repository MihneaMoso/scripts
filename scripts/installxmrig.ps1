# XMRig Automated Installer & Configurator (Admin Mode)
# IMPORTANT: This script is for educational and authorized use only.
# Ensure you have permission to mine on this machine.

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
$WalletAddress = "YOUR_WALLET_ADDRESS_HERE" # <--- REPLACE THIS
$PoolUrl = "pool.supportxmr.com:3333"
$Coin = "monero"

# --- Prerequisites ---
if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
    Write-Error "curl.exe is not found. Please use Windows 10/11 or install curl."
    exit 1
}

# --- Installation ---
# Create Directory
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
    Write-Host "Created directory: $InstallDir" -ForegroundColor Green
}

# Download XMRig
Write-Host "Fetching latest release URL..." -ForegroundColor Cyan
try {
    # Force TLS 1.2 for GitHub API compatibility
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/xmrig/xmrig/releases/latest"
    $DownloadUrl = ($LatestRelease.assets | Where-Object { $_.name -like "*gcc-win64.zip" }).browser_download_url
    
    if (-not $DownloadUrl) { throw "Could not find a Windows gcc-win64 zip file." }
    
    $ZipFile = "$InstallDir\xmrig.zip"
    Write-Host "Downloading from: $DownloadUrl" -ForegroundColor Cyan
    & curl.exe -L -o "$ZipFile" "$DownloadUrl"

    if (-not (Test-Path $ZipFile)) { throw "Download failed." }
}
catch {
    Write-Error "Failed to download XMRig: $_"
    exit 1
}

# Extract
Write-Host "Extracting files..." -ForegroundColor Cyan
Expand-Archive -Path $ZipFile -DestinationPath $InstallDir -Force
Remove-Item -Path $ZipFile

# Locate Binary
$ExtractedFolder = Get-ChildItem -Path $InstallDir -Directory | Select-Object -First 1
$ExePath = "$($ExtractedFolder.FullName)\xmrig.exe"

if (-not (Test-Path $ExePath)) {
    Write-Warning "Could not locate xmrig.exe automatically."
}

# --- Config Generation ---
Write-Host "Generating config.json..." -ForegroundColor Cyan

$Config = @{
    "api" = @{ "id" = $null; "worker-id" = $null }
    "http" = @{ "enabled" = $false; "host" = "127.0.0.1"; "port" = 0; "access-token" = $null; "restricted" = $true }
    "autosave" = $true
    "background" = $false
    "colors" = $true
    "title" = $true
    "randomx" = @{ "init" = -1; "init-avx2" = -1; "mode" = "auto"; "1gb-pages" = $false; "rdmsr" = $true; "wrmsr" = $true; "cache_qos" = $false; "numa" = $true; "scratchpad_prefetch_mode" = 1 }
    "cpu" = @{ "enabled" = $true; "huge-pages" = $true; "huge-pages-jit" = $false; "hw-aes" = $null; "priority" = $null; "memory-pool" = $false; "yield" = $true; "asm" = $true; "argon2-impl" = $null; "astrobwt-max-size" = 550; "astrobwt-avx2" = $false; "cn/0" = $false; "cn-lite/0" = $false }
    "opencl" = @{ "enabled" = $false; "cache" = $true; "loader" = $null; "platform" = "AMD"; "adl" = $true }
    "cuda" = @{ "enabled" = $false; "loader" = $null; "nvml" = $true }
    "log-file" = "xmrig.log"
    "donate-level" = 1
    "donate-over-proxy" = 1
    "pools" = @(
        @{
            "algo" = $null
            "coin" = $Coin
            "url" = $PoolUrl
            "user" = $WalletAddress
            "pass" = "x"
            "rig-id" = $null
            "nicehash" = $false
            "keepalive" = $true
            "enabled" = $true
            "tls" = $false
            "tls-fingerprint" = $null
            "daemon" = $false
            "socks5" = $null
            "self-select" = $null
            "submit-to-origin" = $false
        }
    )
    "print-time" = 60
    "health-print-time" = 60
    "retries" = 5
    "retry-pause" = 5
    "syslog" = $false
    "tls" = @{ "enabled" = $false; "protocols" = $null; "cert" = $null; "cert_key" = $null; "ciphers" = $null; "ciphersuites" = $null; "dhparam" = $null }
    "user-agent" = $null
    "verbose" = 0
    "watch" = $true
    "pause-on-battery" = $false
    "pause-on-active" = $false
}

$JsonContent = $Config | ConvertTo-Json -Depth 10
Set-Content -Path "$($ExtractedFolder.FullName)\config.json" -Value $JsonContent

Write-Host "---------------------------------------------------" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "Location: $($ExtractedFolder.FullName)"
Write-Host "To run, use: & '$ExePath'"
Write-Host "---------------------------------------------------"

