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

## Collection

The Wazuh agent collects the Security channel by default. The PowerShell channel is added in [`agent.conf`](../../infrastructure/wazuh/shared/default/agent.conf).
