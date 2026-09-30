#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Sysmon with the SentinelForge baseline config, or updates the config if Sysmon is already installed.

.DESCRIPTION
    Downloads sysmonconfig.xml from this repo and Sysmon from Sysinternals, then verifies both before running:
    the config against its pinned SHA256, and Sysmon64.exe against a valid Microsoft Authenticode signature.

.EXAMPLE
    # On the lab endpoint, in an elevated PowerShell:
    irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/telemetry/sysmon/Install-Sysmon.ps1 -OutFile $env:TEMP\Install-Sysmon.ps1
    powershell -ExecutionPolicy Bypass -File $env:TEMP\Install-Sysmon.ps1
#>
param(
    [string] $ConfigUrl = 'https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/telemetry/sysmon/sysmonconfig.xml',
    [string] $ConfigSha256 = 'F115AAC5770DAE468E5CFB48C58A8B6E37588208A31F1B746812C534577A244B'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on PS 5.1

$work = Join-Path $env:TEMP 'sentinelforge-sysmon'
New-Item -ItemType Directory -Force $work | Out-Null

$config = Join-Path $work 'sysmonconfig.xml'
Invoke-WebRequest $ConfigUrl -OutFile $config -UseBasicParsing
$hash = (Get-FileHash $config -Algorithm SHA256).Hash
if ($hash -ne $ConfigSha256) { throw "sysmonconfig.xml SHA256 mismatch: got $hash" }

$zip = Join-Path $work 'Sysmon.zip'
Invoke-WebRequest 'https://download.sysinternals.com/files/Sysmon.zip' -OutFile $zip -UseBasicParsing
Expand-Archive $zip -DestinationPath $work -Force
$exe = Join-Path $work 'Sysmon64.exe'
$sig = Get-AuthenticodeSignature $exe
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    throw "Sysmon64.exe signature check failed: $($sig.Status) $($sig.SignerCertificate.Subject)"
}

if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
    & $exe -c $config
} else {
    & $exe -accepteula -i $config
}
if ($LASTEXITCODE -ne 0) { throw "Sysmon64.exe exited with code $LASTEXITCODE" }

Get-Service Sysmon64 | Format-Table Name, Status -AutoSize
Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 3 | Format-Table TimeCreated, Id, TaskDisplayName -AutoSize
