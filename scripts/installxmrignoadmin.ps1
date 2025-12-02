# XMRig Automated Installer & Configurator
# IMPORTANT: This script is for educational and authorized use only.
# Ensure you have permission to mine on this machine.

# --- Configuration ---
$InstallDir = "C:\XMRig"
$WalletAddress = "49G3kemCgBBPhjNK1gizHMR8V7qq5nMzrHz6BtETnqzSBTAs4tWCh7tWA9HZW6YhqHHwGUaX5t8EmjUyEe8FQPakU19pr8i" # <--- REPLACE THIS WITH YOUR ACTUAL WALLET
$PoolUrl = "pool.supportxmr.com:3333"       # Example pool, change as needed
$Coin = "monero"                            # Usually 'monero' for RandomX

# --- Prerequisites ---
# Ensure curl is available
if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
    Write-Error "curl.exe is not found in your PATH. Please install it or use Windows 10/11."
    exit 1
}

# Create Installation Directory
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
    Write-Host "Created directory: $InstallDir" -ForegroundColor Green
}

# --- Download XMRig ---
Write-Host "Fetching latest release information..." -ForegroundColor Cyan

# We use GitHub API to find the latest asset URL for Windows (GCC version is standard)
# Note: We are using native PowerShell for the API call to parse JSON easily, but curl for the download as requested.
try {
    $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/xmrig/xmrig/releases/latest"
    $DownloadUrl = ($LatestRelease.assets | Where-Object { $_.name -like "*gcc-win64.zip" }).browser_download_url
    
    if (-not $DownloadUrl) {
        throw "Could not find a Windows gcc-win64 zip file in the latest release."
    }
    
    $ZipFile = "$InstallDir\xmrig.zip"
    
    Write-Host "Downloading XMRig from: $DownloadUrl" -ForegroundColor Cyan
    # Using curl.exe as requested
    & curl.exe -L -o "$ZipFile" "$DownloadUrl"

    if (-not (Test-Path $ZipFile)) {
        throw "Download failed."
    }
}
catch {
    Write-Error "Failed to download XMRig: $_"
    exit 1
}

# --- Extraction ---
Write-Host "Extracting files..." -ForegroundColor Cyan
Expand-Archive -Path $ZipFile -DestinationPath $InstallDir -Force

# Cleanup Zip
Remove-Item -Path $ZipFile

# Find the extracted folder (usually xmrig-x.x.x) and move contents up or identify the binary
$ExtractedFolder = Get-ChildItem -Path $InstallDir -Directory | Select-Object -First 1
$ExePath = "$($ExtractedFolder.FullName)\xmrig.exe"

if (-not (Test-Path $ExePath)) {
    Write-Warning "Could not locate xmrig.exe automatically. Please check $InstallDir."
} else {
    Write-Host "XMRig executable found at: $ExePath" -ForegroundColor Green
}

# --- Configuration ---
Write-Host "Generating config.json..." -ForegroundColor Cyan

# Basic Configuration Template
# This sets up the mining pool, wallet, and basic CPU settings.
$Config = @{
    "api" = @{
        "id" = $null
        "worker-id" = $null
    }
    "http" = @{
        "enabled" = $false
        "host" = "127.0.0.1"
        "port" = 0
        "access-token" = $null
        "restricted" = $true
    }
    "autosave" = $true
    "background" = $false
    "colors" = $true
    "title" = $true
    "randomx" = @{
        "init" = -1
        "init-avx2" = -1
        "mode" = "auto"
        "1gb-pages" = $false
        "rdmsr" = $true
        "wrmsr" = $true
        "cache_qos" = $false
        "numa" = $true
        "scratchpad_prefetch_mode" = 1
    }
    "cpu" = @{
        "enabled" = $true
        "huge-pages" = $true
        "huge-pages-jit" = $false
        "hw-aes" = $null
        "priority" = $null
        "memory-pool" = $false
        "yield" = $true
        "asm" = $true
        "argon2-impl" = $null
        "astrobwt-max-size" = 550
        "astrobwt-avx2" = $false
        "cn/0" = $false
        "cn-lite/0" = $false
    }
    "opencl" = @{
        "enabled" = $false
        "cache" = $true
        "loader" = $null
        "platform" = "AMD"
        "adl" = $true
    }
    "cuda" = @{
        "enabled" = $false
        "loader" = $null
        "nvml" = $true
    }
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
    "tls" = @{
        "enabled" = $false
        "protocols" = $null
        "cert" = $null
        "cert_key" = $null
        "ciphers" = $null
        "ciphersuites" = $null
        "dhparam" = $null
    }
    "user-agent" = $null
    "verbose" = 0
    "watch" = $true
    "pause-on-battery" = $false
    "pause-on-active" = $false
}

# Convert hash table to JSON and save to the correct folder
$JsonContent = $Config | ConvertTo-Json -Depth 10
Set-Content -Path "$($ExtractedFolder.FullName)\config.json" -Value $JsonContent

Write-Host "---------------------------------------------------" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "1. Location: $($ExtractedFolder.FullName)"
Write-Host "2. Config:   $($ExtractedFolder.FullName)\config.json"
Write-Host "3. Wallet:   $WalletAddress (Check this!)"
Write-Host "---------------------------------------------------"
Write-Host "To start mining, navigate to the folder and run xmrig.exe as Administrator (for Huge Pages support)." -ForegroundColor Yellow

