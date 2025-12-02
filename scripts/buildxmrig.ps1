# XMRig Source Compiler & Installer
# Automated script to set up a dev environment, clone, and compile XMRig on Windows.

# --- 1. Self-Elevation & Admin Check ---
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "Not running as Administrator. Attempting to elevate..." -ForegroundColor Yellow
    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } else {
        Write-Error "Please run your terminal as Administrator before executing this script via IEX."
        exit 1
    }
}

# --- 2. Configuration ---
$BaseDir = "C:\"
$BuildEnvDir = "C:\XMRig_Build_Env" # Temporary build environment
$InstallDir = "C:\XMRig"            # Final destination
$WalletAddress = "49G3kemCgBBPhjNK1gizHMR8V7qq5nMzrHz6BtETnqzSBTAs4tWCh7tWA9HZW6YhqHHwGUaX5t8EmjUyEe8FQPakU19pr8i" # <--- REPLACE THIS
$PoolUrl = "pool.supportxmr.com:3333"
$MSYS2_URL = "https://github.com/msys2/msys2-installer/releases/download/2024-01-13/msys2-base-x86_64-20240113.tar.xz"

# --- 3. Defender Exclusion ---
# Critical: Defender often deletes the compiler output immediately.
Write-Host "Adding Defender exclusions for build and install directories..." -ForegroundColor Cyan
try {
    Add-MpPreference -ExclusionPath $BuildEnvDir -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue
    Write-Host "Exclusions added." -ForegroundColor Green
} catch {
    Write-Warning "Could not add Defender exclusions. You might need to do this manually if the build fails."
}

# --- 4. Setup Build Environment (MSYS2) ---
if (-not (Test-Path "$BuildEnvDir\msys64\usr\bin\bash.exe")) {
    Write-Host "Downloading MSYS2 Build Environment (This may take a moment)..." -ForegroundColor Cyan
    $Archive = "$BaseDir\msys2.tar.xz"
    
    # Download MSYS2
    & curl.exe -L -o "$Archive" "$MSYS2_URL"
    
    if (-not (Test-Path $Archive)) { throw "Failed to download MSYS2." }

    Write-Host "Extracting MSYS2 (This takes time)..." -ForegroundColor Cyan
    # Use native tar (available in Win10/11)
    cd $BaseDir
    tar -xf "msys2.tar.xz"
    
    # Rename default extracted folder if necessary, usually it extracts as msys64
    if (Test-Path "$BaseDir\msys64") {
        Move-Item "$BaseDir\msys64" "$BuildEnvDir" -Force
    }
    Remove-Item "$Archive"
}

$Bash = "$BuildEnvDir\usr\bin\bash.exe"
if (-not (Test-Path $Bash)) { throw "Could not find bash.exe. MSYS2 setup failed." }

# Helper to run bash commands in MSYS2 environment
function Run-Msys {
    param([string]$Cmd)
    # We use -login to ensure paths are set
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $Bash
    $ProcessInfo.Arguments = "-login -c ""$Cmd"""
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    
    $p = [System.Diagnostics.Process]::Start($ProcessInfo)
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    
    if ($p.ExitCode -ne 0) {
        Write-Error "MSYS2 Command Failed: $Cmd"
        Write-Error $stderr
        throw "Build Error"
    }
    return $stdout
}

# --- 5. Install Dependencies ---
Write-Host "Updating MSYS2 and installing Build Tools (Git, GCC, CMake)..." -ForegroundColor Cyan
Write-Host "This step downloads ~500MB. Please wait." -ForegroundColor Yellow

# Update package database and install deps
# deps: git, make, gcc (mingw64), cmake (mingw64), libuv, openssl, hwloc
$Deps = "git make mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-libuv mingw-w64-x86_64-openssl mingw-w64-x86_64-hwloc"
Run-Msys "pacman -Sy --noconfirm $Deps" | Out-Null
Write-Host "Dependencies installed." -ForegroundColor Green

# --- 6. Clone & Compile ---
Write-Host "Cloning XMRig from GitHub..." -ForegroundColor Cyan
# Clean previous build if exists
Run-Msys "rm -rf xmrig"
Run-Msys "git clone https://github.com/xmrig/xmrig.git" | Out-Null

Write-Host "Configuring Build (CMake)..." -ForegroundColor Cyan
Run-Msys "mkdir -p xmrig/build && cd xmrig/build && /mingw64/bin/cmake .. -G 'Unix Makefiles' -DXMRIG_DEPS=ON" | Out-Null

Write-Host "Compiling XMRig (This taxes the CPU)..." -ForegroundColor Cyan
Run-Msys "cd xmrig/build && make -j$(Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty NumberOfLogicalProcessors)" | Out-Null

# --- 7. Deployment ---
Write-Host "Build Complete. Deploying..." -ForegroundColor Cyan
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }

# The compiled binary is inside the MSYS2 folder structure
$CompiledBin = "$BuildEnvDir\home\$($env:USERNAME)\xmrig\build\xmrig.exe"

# If running as root in msys, it might be in home/Admin
if (-not (Test-Path $CompiledBin)) {
    # Try finding it
    $CompiledBin = Get-ChildItem -Path "$BuildEnvDir\home" -Filter "xmrig.exe" -Recurse | Select-Object -ExpandProperty FullName -First 1
}

if (-not $CompiledBin -or -not (Test-Path $CompiledBin)) {
    throw "Could not locate the compiled 'xmrig.exe'. Build may have failed."
}

Copy-Item -Path $CompiledBin -Destination "$InstallDir\xmrig.exe" -Force
Write-Host "XMRig binary moved to $InstallDir" -ForegroundColor Green

# --- 8. Configuration (Same as before) ---
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

# --- 9. Final Output ---
Write-Host "---------------------------------------------------" -ForegroundColor Green
Write-Host "COMPILATION & INSTALLATION SUCCESSFUL" -ForegroundColor Green
Write-Host "---------------------------------------------------"
Write-Host "1. Binary:   $InstallDir\xmrig.exe"
Write-Host "2. Config:   $InstallDir\config.json"
Write-Host "3. Build Env:$BuildEnvDir (Safe to delete if done)"
Write-Host "---------------------------------------------------"
Write-Host "To run: cd $InstallDir ; ./xmrig.exe" -ForegroundColor Yellow

