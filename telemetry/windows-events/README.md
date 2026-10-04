# Windows Audit Policy

Sysmon covers process, network, file and registry activity. Logons, account and group changes, scheduled task creation and PowerShell script content come from Windows' own logs, and most of that is **off by default**. [`Set-AuditPolicy.ps1`](Set-AuditPolicy.ps1) turns on what the lab's planned detections need.

## What is enabled and why

| Setting | Events | Used for |
|---|---|---|
| Logon (success, failure) | 4624, 4625 | Brute force, logons with stolen credentials |
| Special Logon (success) | 4672 | Admin-privileged sessions |
| Credential Validation (success, failure) | 4776 | NTLM credential checks, password spraying |
| Process Creation (success) + command line | 4688 | Every process, including ones the Sysmon config doesn't log (Notepad, for example) |
| Other Object Access Events (success, failure) | 4698–4702 | Scheduled task created, changed or deleted (T1053.005) |
| User Account Management (success, failure) | 4720, 4722, 4724, 4738 | Account created, enabled, password reset |
| Security Group Management (success) | 4728, 4732 | User added to a privileged group |
| Audit Policy Change (success, failure) | 4719 | Someone turning logging off (defense evasion) |
| PowerShell Script Block Logging | 4104 (`Microsoft-Windows-PowerShell/Operational`) | The script text PowerShell ran, after deobfuscation (T1059.001) |

The script also:

- sets `SCENoApplyLegacyAuditPolicy` so these subcategory settings override older category-level policy
- raises the Security log from 20 MB to 256 MB, because process creation auditing fills the default size quickly

Subcategories are set by GUID, not name, because `auditpol` names are translated on non-English Windows.

## Apply

In an elevated PowerShell on the lab VM:

```powershell
irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/telemetry/windows-events/Set-AuditPolicy.ps1 -OutFile $env:TEMP\Set-AuditPolicy.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\Set-AuditPolicy.ps1
```

The output lists each subcategory with its new setting.

Script block logging only applies to PowerShell processes started **after** the policy is set. A console that was already open keeps logging nothing to 4104.

## Verified on the lab VM (2026-10-03)

One command, run in a new PowerShell process:

```powershell
powershell -NoProfile -Command Write-Output sentinelforge-4104-new
```

produced three events in Wazuh (`wazuh-archives-*`), one per log source:

| Channel | Event ID | What it records |
|---|---|---|
| Security | 4688 | `powershell.exe -NoProfile -Command ...` with the full command line |
| Microsoft-Windows-Sysmon/Operational | 1 | The same process, plus hashes, parent process and GUIDs |
| Microsoft-Windows-PowerShell/Operational | 4104 | The script block that actually ran: `Write-Output sentinelforge-4104-new` |

4104 is the one that survives obfuscation. With `powershell -enc <base64>`, 4688 and Sysmon only show the encoded string, while 4104 shows the decoded script.

## Collection

The Wazuh agent collects the Security channel by default. The PowerShell channel is added in [`agent.conf`](../../infrastructure/wazuh/shared/default/agent.conf).
