# installnotepadpp.ps1
# Admin-free installer for Notepad++ (portable)
# - Downloads latest portable ZIP from GitHub releases
# - Extracts to a user-writable folder
# - Optionally adds the bin folder to the USER Path and creates a desktop shortcut
# Usage: Save and run, or pipe: iwr -useb <script-url> | iex
Set-StrictMode -Version Latest
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

Write-Host "Starting Notepad++ (portable) installer..." -ForegroundColor Cyan

# ---------- Configuration ----------
$repo = "notepad-plus-plus/notepad-plus-plus"   # GitHub repo
# Where to install (non-admin location)
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\Notepad++-portable"
# Local temp file
$zipFile = Join-Path ([System.IO.Path]::GetTempPath()) "npp-portable.zip"
# Where we will put a small shim or add to PATH; choose user-local bin
$userBin = Join-Path $env:USERPROFILE "bin"
# Whether to add the Notepad++ folder to the USER PATH
$addToUserPath = $true
# Whether to create a Desktop shortcut
$createDesktopShortcut = $true
# Fallback manual URL (optional). Leave empty to use GitHub API only.
$manualDownloadUrl = ""
# -----------------------------------

function Get-File($url, $out) {
    Write-Host "=> Downloading $url ..." -ForegroundColor Cyan
    if (Get-Command -Name curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L -o $out -# $url
        if ($LASTEXITCODE -ne 0) { throw "curl failed with exit code $LASTEXITCODE" }
    } else {
        # Use PowerShell's Invoke-WebRequest as fallback
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    }
}

# Ensure temp path exists and is writable
$tempPath = [System.IO.Path]::GetTempPath()
if (-not (Test-Path $tempPath)) { New-Item -ItemType Directory -Force -Path $tempPath | Out-Null }

# Determine download URL
if ($manualDownloadUrl) {
    $downloadUrl = $manualDownloadUrl
} else {
    Write-Host "=> Querying GitHub for latest Notepad++ release..." -ForegroundColor Cyan
    try {
        $releaseJson = & curl.exe -s "https://api.github.com/repos/$repo/releases/latest" 2>$null
        if (-not $releaseJson) {
            # fallback to Invoke-WebRequest
            $releaseJson = (Invoke-WebRequest -Uri "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing -ErrorAction Stop).Content
        }
        $release = $releaseJson | ConvertFrom-Json
        # Try to pick an asset that looks like a portable zip
        $asset = $release.assets `
            | Where-Object { $_.name -match '(portable|Portable).*zip' -or $_.name -match '\.zip$' } `
            | Select-Object -First 1

        if (-not $asset) {
            throw "No suitable asset found in GitHub release."
        }
        $downloadUrl = $asset.browser_download_url
        Write-Host "Found asset: $($asset.name)" -ForegroundColor Green
    } catch {
        throw "Failed to determine download URL from GitHub: $_"
    }
}

# Download the ZIP
Get-File $downloadUrl $zipFile

# Prepare install directory
Write-Host "=> Installing to $installRoot" -ForegroundColor Cyan
if (Test-Path $installRoot) {
    Write-Host "Removing existing install at $installRoot ..." -ForegroundColor Yellow
    Remove-Item $installRoot -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

# Extract the zip
Write-Host "=> Extracting ..." -ForegroundColor Cyan
# Use Expand-Archive if available (PowerShell 5+)
try {
    Expand-Archive -LiteralPath $zipFile -DestinationPath $installRoot -Force
} catch {
    # Fallback: use System.IO.Compression (handles most zips)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $installRoot)
}

# Many Notepad++ portable zips contain a top-level folder like "npp.x.y\*".
# If the zip extracted into a single subfolder, move its contents up.
$children = Get-ChildItem -LiteralPath $installRoot
if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
    Write-Host "Normalizing extracted folder layout..." -ForegroundColor Yellow
    $inner = $children[0].FullName
    Get-ChildItem -LiteralPath $inner -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $installRoot -Force
    }
    Remove-Item -LiteralPath $inner -Recurse -Force -ErrorAction SilentlyContinue
}

# Cleanup zip
if (Test-Path $zipFile) { Remove-Item $zipFile -Force -ErrorAction SilentlyContinue }

# Try to locate the main executable inside the folder
$nppExe = Get-ChildItem -Path $installRoot -Recurse -Filter 'notepad++.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $nppExe) {
    Write-Warning "Could not find notepad++.exe in the extracted files. Installation may be incomplete."
} else {
    Write-Host "Installed executable: $($nppExe.FullName)" -ForegroundColor Green
}

# Optionally add to USER Path by adding the containing folder of notepad++.exe
if ($addToUserPath -and $nppExe) {
    $nppFolder = $nppExe.Directory.FullName
    $oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($oldPath -notlike "*$nppFolder*") {
        Write-Host "=> Adding $nppFolder to USER Path..." -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("Path", "$oldPath;$nppFolder", "User")
        Write-Host "Added to user PATH. You may need to open a new terminal to see the change." -ForegroundColor Green
    } else {
        Write-Host "PATH already contains Notepad++ folder." -ForegroundColor Yellow
    }
}

# Ensure $userBin exists and create a tiny shim 'npp.cmd' if user prefers quick 'npp' command
if (-not (Test-Path $userBin)) {
    New-Item -ItemType Directory -Force -Path $userBin | Out-Null
}
$shim = Join-Path $userBin "npp.cmd"
if ($nppExe) {
    $shimContent = "@echo off`nstart `"" + $nppExe.FullName + "`" %*"
    Set-Content -LiteralPath $shim -Value $shimContent -Encoding ASCII -Force
    # Add userBin to PATH if not already
    $oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($oldPath -notlike "*$userBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$oldPath;$userBin", "User")
        Write-Host "Added $userBin to USER Path for the 'npp' command." -ForegroundColor Green
    }
}

# Optionally create Desktop shortcut (works for Windows)
if ($createDesktopShortcut -and $nppExe) {
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $desktop = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktop "Notepad++.lnk"
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $nppExe.FullName
        $shortcut.WorkingDirectory = $nppExe.Directory.FullName
        $shortcut.IconLocation = $nppExe.FullName + ",0"
        $shortcut.Save()
        Write-Host "Desktop shortcut created." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to create desktop shortcut: $_"
    }
}

Write-Host ""
Write-Host "Done! You can run Notepad++ from the start menu (shortcut) or by typing 'npp' in a new terminal." -ForegroundColor Green
Write-Host "If you added to PATH you may need to open a new PowerShell / CMD window to see the change." -ForegroundColor Yellow
