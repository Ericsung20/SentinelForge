#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables the Windows audit policy and PowerShell logging that the lab's detections rely on.

.DESCRIPTION
    Subcategories are set by GUID so the script works on any Windows display language.
    Safe to run more than once. See README.md for why each setting is enabled.

.EXAMPLE
    # On the lab endpoint, in an elevated PowerShell:
    irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/telemetry/windows-events/Set-AuditPolicy.ps1 -OutFile $env:TEMP\Set-AuditPolicy.ps1
    powershell -ExecutionPolicy Bypass -File $env:TEMP\Set-AuditPolicy.ps1
#>

$ErrorActionPreference = 'Stop'

# GUID = name, success, failure
$subcategories = [ordered]@{
    '{0CCE9215-69AE-11D9-BED3-505054503030}' = 'Logon', 'enable', 'enable'                      # 4624, 4625
    '{0CCE921B-69AE-11D9-BED3-505054503030}' = 'Special Logon', 'enable', 'disable'             # 4672
    '{0CCE923F-69AE-11D9-BED3-505054503030}' = 'Credential Validation', 'enable', 'enable'      # 4776
    '{0CCE922B-69AE-11D9-BED3-505054503030}' = 'Process Creation', 'enable', 'disable'          # 4688
    '{0CCE9227-69AE-11D9-BED3-505054503030}' = 'Other Object Access Events', 'enable', 'enable' # 4698-4702 scheduled tasks
    '{0CCE9235-69AE-11D9-BED3-505054503030}' = 'User Account Management', 'enable', 'enable'    # 4720, 4722, 4724, 4738
    '{0CCE9237-69AE-11D9-BED3-505054503030}' = 'Security Group Management', 'enable', 'disable' # 4728, 4732
    '{0CCE922F-69AE-11D9-BED3-505054503030}' = 'Audit Policy Change', 'enable', 'enable'        # 4719
}

function Set-Dword([string] $Key, [string] $Name, [int] $Value) {
    # New-Item -Force would recreate an existing key and wipe its values, so only create when missing
    if (-not (Test-Path $Key)) { New-Item $Key -Force | Out-Null }
    Set-ItemProperty $Key -Name $Name -Value $Value -Type DWord
}

# Make subcategory settings win over legacy category-level policy
Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'SCENoApplyLegacyAuditPolicy' 1

foreach ($guid in $subcategories.Keys) {
    $name, $success, $failure = $subcategories[$guid]
    auditpol /set "/subcategory:$guid" "/success:$success" "/failure:$failure" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "auditpol failed for $name ($guid)" }
}

# 4688 records the full command line, not just the executable
Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' 'ProcessCreationIncludeCmdLine_Enabled' 1

# PowerShell script block logging: 4104 in Microsoft-Windows-PowerShell/Operational, with the script text
Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging' 1

# The default 20 MB Security log rolls over within hours once process creation is audited
wevtutil sl Security /ms:268435456
if ($LASTEXITCODE -ne 0) { throw "wevtutil failed to resize the Security log" }

$ids = $subcategories.Keys -join ','
auditpol /get "/subcategory:$ids" /r | ConvertFrom-Csv |
    Format-Table Subcategory, 'Inclusion Setting' -AutoSize
