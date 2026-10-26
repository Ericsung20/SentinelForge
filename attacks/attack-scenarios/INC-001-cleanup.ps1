#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Reverses everything INC-001-multistage.ps1 created. Safe to run more than once.
#>
$ErrorActionPreference = 'Continue'
$tag = 'SF-INC-001'

Remove-Item -Path (Join-Path $env:TEMP "$tag.txt") -Force -ErrorAction Ignore
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $tag -Force -ErrorAction Ignore
schtasks.exe /delete /tn $tag /f 2>$null | Out-Null

Write-Host "[+] INC-001 artifacts removed."
