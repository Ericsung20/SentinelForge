#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SentinelForge lab scenario for investigation INC-003. Benign only.

.DESCRIPTION
    Establishes a single persistence mechanism the way a real intruder would after
    gaining a foothold: a scheduled task that re-launches a staged payload at every
    logon (T1053.005 - Scheduled Task/Job: Scheduled Task).

    Unlike INC-001, the payload file really exists, so the investigation can follow
    the full chain (task -> action -> dropped script). The payload is harmless: it
    only writes a marker file. The task runs at logon, which is never triggered here,
    so nothing actually executes during the exercise. Detection fires on task
    CREATION (Security 4698), not execution.

    Everything is reversed by INC-003-cleanup.ps1. No downloads, no external connections.
    Artifacts use the tag SF-INC-003 so the analyst and the cleanup can find them.
#>
$ErrorActionPreference = 'Stop'
$tag     = 'SF-INC-003'
$dir     = Join-Path $env:ProgramData $tag
$payload = Join-Path $dir 'payload.ps1'
$marker  = Join-Path $env:TEMP "$tag.txt"

Write-Host "[*] Stage A: drop a staged payload (writes a marker file only)"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Set-Content -Path $payload -Value "Set-Content -Path '$marker' -Value 'benign lab marker $tag'"

Write-Host "[*] Stage B: scheduled task re-launches the payload at every logon"
schtasks.exe /create /tn $tag /sc onlogon /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File $payload" /f | Out-Null

Write-Host "[+] Done. Task: $tag  |  payload: $payload  |  cleanup: INC-003-cleanup.ps1"
