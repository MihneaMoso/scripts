# XMRig User-Mode Source Compiler
# Compiles XMRig from source without Admin rights.
# PREREQUISITES: Git, CMake, Make (or MinGW32-make), GCC/G++, and Libuv/OpenSSL dev libs must be in your PATH.

# --- Configuration ---
$BaseDir = "$env:USERPROFILE\xmrig-source"
$InstallDir = "$env:USERPROFILE\xmrig"
$WalletAddress = "49G3kemCgBBPhjNK1gizHMR8V7qq5nMzrHz6BtETnqzSBTAs4tWCh7tWA9HZW6YhqHHwGUaX5t8EmjUyEe8FQPakU19pr8i" # <--- REPLACE THIS
$PoolUrl = "pool.supportxmr.com:3333"

# --- 1. Environment Check ---
Write-Host "Checking for build tools..." -ForegroundColor Cyan

$RequiredTools = @("git", "cmake", "g++")
foreach ($tool in $RequiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Error: '$tool' is not found in your PATH."
        Write-Host "This script assumes you have a pre-configured build environment."
        exit 1
    }
}

# Detect Make command (support for MinGW or Standard Make)
$MakeCmd = "make"
$Generator = "Unix Makefiles"

if (Get-Command "mingw32-make" -ErrorAction SilentlyContinue) {
    $MakeCmd = "mingw32-make"
    $Generator = "MinGW Makefiles"
    Write-Host "Detected MinGW environment." -ForegroundColor Green
} elseif (Get-Command "make" -ErrorAction SilentlyContinue) {
    Write-Host "Detected Standard Make environment." -ForegroundColor Green
} else {
    Write-Error "Error: Could not find 'make' or 'mingw32-make'."
    exit 1
}

# --- 2. Clone Repository ---
if (Test-Path $BaseDir) {
    Write-Host "Cleaning previous source directory..." -ForegroundColor Yellow
    Remove-Item -Path $BaseDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Cloning XMRig from GitHub..." -ForegroundColor Cyan
try {
    & git clone https://github.com/xmrig/xmrig.git "$BaseDir"
} catch {
    Write-Error "Git clone failed. Please check your internet connection."
    exit 1
}

# --- 3. Compile ---
$BuildDir = "$BaseDir\build"
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Set-Location -Path $BuildDir

Write-Host "Configuring build with CMake..." -ForegroundColor Cyan
# We use -DXMRIG_DEPS=ON to attempt to locate dependencies. 
# If your environment lacks Libuv/OpenSSL dev libraries, this step will fail.
try {
    & cmake .. -G "$Generator" -DXMRIG_DEPS=ON -DCMAKE_BUILD_TYPE=Release
    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed." }
} catch {
    Write-Error "CMake failed. Ensure you have Libuv, OpenSSL, and Hwloc libraries installed and visible to CMake."
    exit 1
}

Write-Host "Compiling (This depends on your CPU speed)..." -ForegroundColor Cyan
try {
    # Get CPU core count for parallel build
    $Cores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    & $MakeCmd -j$Cores
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed." }
} catch {
    Write-Error "Build failed during compilation."
    exit 1
}

# --- 4. Deployment ---
Write-Host "Deploying to $InstallDir..." -ForegroundColor Cyan

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$CompiledBin = "$BuildDir\xmrig.exe"

if (-not (Test-Path $CompiledBin)) {
    Write-Error "Build finished but 'xmrig.exe' is missing."
    Write-Host "CRITICAL WARNING: Windows Defender likely deleted the file immediately." -ForegroundColor Red
    Write-Host "Check 'Windows Security > Virus & threat protection > Protection history' to restore it." -ForegroundColor Yellow
    exit 1
}

Copy-Item -Path $CompiledBin -Destination "$InstallDir\xmrig.exe" -Force

# --- 5. Configuration ---
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
            "coin" = "monero"
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
Set-Content -Path "$InstallDir\config.json" -Value $JsonContent

# --- 6. Cleanup ---
# Optional: Clean up source files to save space
# Remove-Item -Path $BaseDir -Recurse -Force

# --- 7. Final Output ---
Write-Host "---------------------------------------------------" -ForegroundColor Green
Write-Host "BUILD COMPLETE (User Mode)" -ForegroundColor Green
Write-Host "---------------------------------------------------"
Write-Host "Location: $InstallDir\xmrig.exe"
Write-Host "Config:   $InstallDir\config.json"
Write-Host ""
Write-Host "NOTE 1: If 'xmrig.exe' is missing, Windows Defender ate it." -ForegroundColor Red
Write-Host "NOTE 2: Without Admin, 'Huge Pages' will be unavailable (lower hashrate)." -ForegroundColor Yellow
Write-Host "To run:   cd $InstallDir ; ./xmrig.exe" -ForegroundColor Green

