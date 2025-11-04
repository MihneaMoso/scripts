# downloadpico.ps1
# Made by @MihneaMoso
# Copyright © 2025 Mihnea Moso

Set-StrictMode -Version Latest
$VerbosePreference = "Continue"

Write-Verbose "Starting script..."

# 0.  Self-elevate execution-policy for THIS process only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"


$colors = @("red", "fuchsia", "purple", "violet", "indigo", "blue", "cyan", "jade", "green", "lime", "yellow", "amber", "pumpkin", "orange", "sand", "grey", "zinc", "slate")
$output_dir = "css\"
if (-not (Test-Path $output_dir)) {
    New-Item -ItemType Directory -Path $output_dir
}

foreach ($color in $colors) {
    $color_url = "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.{0}.min.css" -f $color
    $output_path = $output_dir + "pico.{0}.min.css" -f $color
    curl.exe $color_url -o $output_path
}

Write-Verbose "Ending script."