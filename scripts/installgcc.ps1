# install-mingw-fast.ps1
# Made by @MihneaMoso
# Copyright © 2025 Mihnea Moso
# Admin-free, *fast* installer for latest MinGW-w64 GCC/G++ on Windows 11.
# Uses curl.exe + 7-Zip portable (auto-downloaded if missing).

Set-StrictMode -Version Latest
$VerbosePreference = "Continue"

Write-Verbose "Starting script..."


# 0.  Self-elevate execution-policy for THIS process only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"

# 1.  CONFIG ------------------------------------------------------------------
$repo        = "brechtsanders/winlibs_mingw"
$installDir  = "$env:USERPROFILE\.local\mingw64"
$binDir      = "$installDir\mingw64\bin"
$zip         = "$env:TEMP\mingw-w64-latest.zip"
$7zDir       = "$env:USERPROFILE\.local\7zip"
$7zExe       = "$7zDir\7z.exe"
# ----------------------------------------------------------------------------

# 2.  Helper: download with curl.exe (5-10x faster than IWR)
function Get-File($url, $out) {
    Write-Host "=> Downloading $url ..." -ForegroundColor Cyan
    & curl.exe -L -o $out -# $url
    if ($LASTEXITCODE) { throw "curl failed" }
}

# 3.  Ensure 7-Zip portable ---------------------------------------------------
if (!(Test-Path $7zExe)) {
    Write-Host "=> 7-Zip not found - fetching portable build ..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force $7zDir | Out-Null
    
    # Download 7-Zip MSI installer instead of broken zip
    $7zInstallerUrl = "https://www.7-zip.org/a/7z2408-x64.msi"
    $7zInstaller = "$env:TEMP\7z-installer.msi"
    Get-File $7zInstallerUrl $7zInstaller
    
    # Extract MSI to get 7z.exe without actually installing
    Write-Host "=> Extracting 7-Zip from MSI ..." -ForegroundColor Yellow
    $extractDir = "$env:TEMP\7z-extract"
    New-Item -ItemType Directory -Force $extractDir | Out-Null
    
    # Use msiexec to extract files
    Start-Process -Wait -WindowStyle Hidden -FilePath "msiexec.exe" -ArgumentList "/a", "`"$7zInstaller`"", "/qn", "TARGETDIR=`"$extractDir`""
    
    # Copy the extracted 7-Zip files to our directory
    $extractedFilesDir = "$extractDir\Files\7-Zip"
    if (Test-Path $extractedFilesDir) {
        Copy-Item "$extractedFilesDir\*" $7zDir -Recurse -Force
    }
    
    # Clean up
    Remove-Item $7zInstaller -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

# 4.  Query GitHub API for latest release -------------------------------------
Write-Host "=> Querying GitHub API ..." -ForegroundColor Cyan
$release = curl.exe -s "https://api.github.com/repos/$repo/releases/latest" | ConvertFrom-Json
$asset   = $release.assets |
           Where-Object { $_.name -match 'winlibs-x86_64.*posix-seh.*\.zip$' } |
           Select-Object -First 1
if (!$asset) { throw "No suitable x86_64 UCRT zip found." }

# 5.  Download MinGW archive --------------------------------------------------
Get-File $asset.browser_download_url $zip

# 6.  Extract with 7-Zip ------------------------------------------------------
Write-Host "=> Extracting ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force $installDir | Out-Null
Remove-Item "$installDir\mingw64" -Recurse -Force -ErrorAction SilentlyContinue
& $7zExe x $zip "-o$installDir" -y | Out-Null
if ($LASTEXITCODE) { throw "7-Zip extraction failed" }

# 7.  Add to USER Path --------------------------------------------------------
Write-Host "=> Adding $binDir to USER Path ..." -ForegroundColor Cyan
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($oldPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$oldPath;$binDir", "User")
}

# 8.  Clean up ----------------------------------------------------------------
Remove-Item $zip -Force -ErrorAction SilentlyContinue

Write-Host @"

All done!  Open a **new** PowerShell or CMD window and run:

    gcc --version
    g++ --version

to confirm the freshly installed MinGW-w64 toolchain.
"@ -ForegroundColor Green

Write-Verbose "Ending script."
