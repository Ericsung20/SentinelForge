# INC-003: Scheduled Task Logon Persistence

| Field | Value |
|---|---|
| **Incident ID** | INC-003 |
| **Title** | Scheduled task `\SF-INC-003` created to run PowerShell at every logon |
| **Date** | 2026-10-28 |
| **Severity** | High |
| **MITRE ATT&CK Technique** | T1053.005: Scheduled Task/Job: Scheduled Task |
| **Status** | Closed |
| **Analyst** | Ericsung20 |

## Summary

An elevated PowerShell session created a scheduled task, `\SF-INC-003`, configured to launch
`powershell.exe` against a staged script (`C:\ProgramData\SF-INC-003\payload.ps1`) at **every logon**.
Rule 100120 fired at level 10 on the Security 4698 task-creation event. Following the process tree
back confirms a deliberate persistence mechanism established from an administrative context — a
**true positive** for T1053.005. The payload in this lab is benign (it only writes a marker file),
but the behaviour is exactly what an intruder uses to survive reboots and re-logons.

## Alert

| Field | Value |
|---|---|
| Rule ID / name | 100120 — Scheduled task runs a script interpreter at boot or logon |
| Level | 10 |
| Timestamp (UTC) | 2026-10-28 06:59:51.830 |
| Host / agent | DESKTOP-3UDQ08I (agent 001) |

Rule 100120 is a child of built-in rule 60228 (Security 4698). It matches when the task XML contains a
`Boot`/`Logon` trigger **and** an action whose command is a script interpreter
(`cmd`, `powershell`, `pwsh`, `wscript`, `cscript`, `mshta`, `rundll32`, `regsvr32`).

## Process

| Field | Value |
|---|---|
| **Process** | `C:\Windows\System32\schtasks.exe` |
| **Parent Process** | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` (interactive admin console) |
| **Command Line** | `schtasks.exe /create /tn SF-INC-003 /sc onlogon /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\ProgramData\SF-INC-003\payload.ps1" /f` |
| **User** | `labuser` (SID `S-1-5-21-...-1001`) |
| Token elevation | `%%1937` — TokenElevationTypeFull (**elevated**) |

The registered task itself runs `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File
C:\ProgramData\SF-INC-003\payload.ps1` under `labuser` with a `LogonTrigger`.

Full export: [`evidence/scheduled-task-creation.txt`](evidence/scheduled-task-creation.txt).

## Related Events

| Time (UTC) | Source | Event ID | Description |
|---|---|---|---|
| 06:09:55.840 | Sysmon | 11 | `powershell.exe` writes the payload `C:\ProgramData\SF-INC-003\payload.ps1` |
| 06:59:44.257 | Security | 4688 | `powershell.exe -File INC-003-persistence.ps1` (elevated, parent = admin console) |
| 06:59:50.746 | Security | 4688 | `schtasks.exe /create /tn SF-INC-003 /sc onlogon /tr "powershell ..." /f` (elevated) |
| 06:59:51.770 | Sysmon | 11 | `svchost.exe` writes `C:\Windows\System32\Tasks\SF-INC-003` (task persisted to disk) |
| 06:59:51.830 | Security | 4698 | Scheduled task created → **rule 100120 (level 10)** |

## Timeline

| Time (UTC) | Event |
|---|---|
| 06:09:55 | Attacker stages the payload script under `C:\ProgramData\SF-INC-003\` |
| 06:59:44 | Elevated `powershell.exe` runs the persistence script |
| 06:59:50 | It invokes `schtasks /create` for a logon-triggered task |
| 06:59:51 | The Schedule service registers `\SF-INC-003`; 4698 fires rule 100120 |
| (at next logon) | the task *would* launch `payload.ps1` — never triggered during the exercise |

## Evidence

- `evidence/scheduled-task-creation.txt`: the 4698 alert, decoded task XML, the elevated 4688 creation chain, and the Sysmon file-create events.
- `screenshots/`: Wazuh dashboard capture of alert 100120 (optional).
