# winadmin.ps1
# Made by @MihneaMoso
# Copyright © 2025 Mihnea Moso

Set-StrictMode -Version Latest
$VerbosePreference = "Continue"

Write-Verbose "Starting script..."
Write-Host "Welcome!"


$path = Read-Host "Enter path to executable: "
Write-Host "Executing $path..."
C:\Windows\System32\cmd.exe /min /C "set __COMPAT_LAYER=RUNASINVOKER && start `"`" `"$path`""


Write-Verbose "Ending script."