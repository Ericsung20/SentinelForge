#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SentinelForge lab scenario for investigation INC-001. Benign only.

.DESCRIPTION
    Chains three stages a real intruder runs after landing on a host, using only harmless commands:
      1. Local account discovery (reads information, changes nothing).
      2. "Encoded" PowerShell that writes a single marker file under the user's temp folder.
      3. Two persistence entries that point at a file that does not exist, so nothing ever launches.
    Everything is reversed by INC-001-cleanup.ps1. No downloads, no external connections.
    Markers use the tag SF-INC-001 so the analyst and the cleanup can find every artifact.
#>
$ErrorActionPreference = 'Stop'
$tag = 'SF-INC-001'
$marker = Join-Path $env:TEMP "$tag.txt"

Write-Host "[*] Stage 1: account discovery"
cmd.exe /c "net user & net localgroup Administrators & cmdkey.exe /list" | Out-Null

Write-Host "[*] Stage 2: encoded PowerShell writes a marker file"
$inner = "Set-Content -Path '$marker' -Value 'benign lab marker $tag'"
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))
powershell.exe -NoProfile -EncodedCommand $enc

Write-Host "[*] Stage 3: persistence (Run key + scheduled task, both point at a non-existent file)"
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $tag -Value "C:\ProgramData\$tag\does-not-exist.exe"
schtasks.exe /create /tn $tag /sc onlogon /tr "cmd.exe /c C:\ProgramData\$tag\does-not-exist.exe" /f | Out-Null

Write-Host "[+] Done. Marker: $marker  |  cleanup: INC-001-cleanup.ps1"
