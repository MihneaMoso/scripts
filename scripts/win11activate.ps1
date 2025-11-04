# win11activate.ps1
# Made by @MihneaMoso
# Copyright © 2025 Mihnea Moso

Set-StrictMode -Version Latest
$VerbosePreference = "Continue"

Write-Verbose "Starting script..."


# 0.  Self-elevate execution-policy for THIS process only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"


slmgr /ipk W269N-WFGWX-YVC9B-4J6C9-T83GX
slmgr /skms kms8.msguides.com
slmgr /ato

Write-Verbose "Ending script."
