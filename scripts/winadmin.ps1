Write-Host "Welcome!"
$path = Read-Host "Enter path to executable: "
Write-Host "Executing $path..."
C:\Windows\System32\cmd.exe /min /C "set __COMPAT_LAYER=RUNASINVOKER && start `"`" `"$path`""