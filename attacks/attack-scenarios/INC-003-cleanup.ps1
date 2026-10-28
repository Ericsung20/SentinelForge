#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Reverses everything INC-003-persistence.ps1 created. Safe to run more than once.
#>
$ErrorActionPreference = 'Continue'
$tag = 'SF-INC-003'

schtasks.exe /delete /tn $tag /f 2>$null | Out-Null
Remove-Item -Path (Join-Path $env:ProgramData $tag) -Recurse -Force -ErrorAction Ignore
Remove-Item -Path (Join-Path $env:TEMP "$tag.txt") -Force -ErrorAction Ignore

Write-Host "[+] INC-003 artifacts removed."
