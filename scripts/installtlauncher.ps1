# Script made by @MihneaMoso
# Copyright © 2025 Mihnea Moso

$username = $Env:UserName
$downloads = "C:\Users\$username\Downloads\"
# curl.exe https://mmoso.vercel.app/icons/favicon.ico -o favicon.ico
$tlauncher_url = "https://dl2.tlauncher.org/f.php?f=files%2FTLauncher-Installer-1.9.3.exe"
$tlauncher_path = "$downloads\tlauncher_installer.exe"
curl.exe $tlauncher_url -o "$tlauncher_path"
C:\Windows\System32\cmd.exe /min /C "set __COMPAT_LAYER=RUNASINVOKER && start `"`" `"$tlauncher_path`""