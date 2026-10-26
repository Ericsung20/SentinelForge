# INC-001: Multi-Stage PowerShell Intrusion on the Lab Endpoint

| Field | Value |
|---|---|
| **Incident ID** | INC-001 |
| **Title** | Account discovery, encoded PowerShell execution and dual persistence on DESKTOP-3UDQ08I |
| **Date** | 2026-10-26 |
| **Severity** | High |
| **MITRE ATT&CK Technique** | T1087.001 (Discovery), T1059.001 + T1027 (Execution / Obfuscation), T1547.001 + T1053.005 (Persistence) |
| **Status** | Closed |
| **Analyst** | Ericsung20 |

## Summary

A burst of local account-discovery commands by `labuser` raised a level-10 alert (rule 100141). Pivoting from that alert, a single PowerShell process (PID 5656) was found to drive a three-stage sequence over about 90 seconds: reconnaissance, an obfuscated (`-EncodedCommand`) PowerShell payload, and two persistence mechanisms. This matches the behaviour of a hands-on intruder after initial access. In this lab the activity was a planned exercise ([`attacks/attack-scenarios/INC-001-multistage.ps1`](../../attacks/attack-scenarios/INC-001-multistage.ps1)); the report is written as if the cause were unknown, to exercise the investigation workflow.

## Alert

The investigation started from the highest-severity alert:

| Field | Value |
|---|---|
| Rule ID / name | 100141 — Account discovery burst: 3+ enumeration commands within 60 seconds |
| Level | 10 |
| Timestamp (UTC) | 2026-10-26 17:55:42 |
| Host / agent | DESKTOP-3UDQ08I (agent 001) |

Four custom detections fired during the incident:

| Time (UTC) | Rule | Level | Stage |
|---|---|---|---|
| 17:55:42 | 100141 account discovery burst | 10 | 1 — discovery |
| 17:55:42–43 | 100140 account discovery command (×4) | 3 | 1 — discovery |
| 17:55:55 | 100130 Run key set by script interpreter | 10 | 3 — persistence |
| 18:10:52 | 100120 scheduled task runs interpreter at logon | 10 | 3 — persistence |

## Process

The root of the activity, from which every stage descends:

| Field | Value |
|---|---|
| **Process** | `powershell.exe` (PID 5656) |
| **Parent Process** | `powershell.exe` (PID 4676, the interactive admin console) |
| **Command Line** | `powershell.exe -ExecutionPolicy Bypass -File $env:TEMP\s.ps1` |
| **User** | DESKTOP-3UDQ08I\labuser |

## Related Events

Reconstructed from Sysmon (process create 1, registry 13, file 11) and PowerShell 4104. Full export: [`evidence/process-tree.txt`](evidence/process-tree.txt).

| Time (UTC) | Source | Event | Detail |
|---|---|---|---|
| 17:55:42.451 | Sysmon 1 | cmd.exe (1616) ← ps 5656 | `cmd /c "net user & net localgroup Administrators & cmdkey /list"` |
| 17:55:42.458 | Sysmon 1 | net.exe (1772) ← cmd 1616 | `net user` |
| 17:55:42.476 | Sysmon 1 | net.exe (5508) ← cmd 1616 | `net localgroup Administrators` |
| 17:55:43.668 | Sysmon 1 | cmdkey.exe (8992) ← cmd 1616 | `cmdkey /list` (looks for saved credentials) |
| 17:55:45.242 | Sysmon 1 | powershell.exe (6352) ← ps 5656 | `powershell -NoProfile -EncodedCommand U...` |
| 17:55:50.783 | PowerShell 4104 | script block of 6352 | decoded: `Set-Content -Path '...\Temp\SF-INC-001.txt' -Value 'benign lab marker SF-INC-001'` |
| 17:55:55.049 | Sysmon 13 | registry set ← powershell | `...\CurrentVersion\Run\SF-INC-001 = C:\ProgramData\SF-INC-001\does-not-exist.exe` |
| 17:56:18.179 | Sysmon 1 | schtasks.exe (5516) ← ps 5656 | `schtasks /create /tn SF-INC-001 /sc onlogon /tr "cmd /c ...does-not-exist.exe"` |
| 18:10:52–54 | Sysmon 13 / 11 ← svchost | Windows writes the task to `TaskCache` and `C:\Windows\System32\Tasks\SF-INC-001` (Task Scheduler service, not the attacker) |

## Timeline

| Time (UTC) | Event |
|---|---|
| 17:55:34 | Attacker script launched (`powershell -File s.ps1`, PID 5656) |
| 17:55:42 | **Stage 1** — account discovery burst (rule 100141 fires) |
| 17:55:45 | **Stage 2** — encoded PowerShell runs |
| 17:55:50 | 4104 reveals the decoded payload: writes a marker file |
| 17:55:55 | **Stage 3a** — Run-key persistence (rule 100130 fires) |
| 17:56:18 | **Stage 3b** — scheduled-task persistence created |
| 18:10:52 | Task Scheduler commits the task to disk; rule 100120 fires |

## Evidence

- `evidence/process-tree.txt`: the process/registry/file timeline for the incident window, generated from Wazuh archives.
- `screenshots/`: (dashboard captures to add).

## Analyst Assessment

**True positive — single actor, multi-stage.** All stages share one process ancestor (PID 5656) and run within about 90 seconds, which is not how normal admin work looks. The `-EncodedCommand` use (T1027) is a strong obfuscation signal on its own; `cmdkey /list` shows intent to harvest saved credentials; and two persistence mechanisms were planted back to back. In a real environment this would be escalated.

The decisive evidence was PowerShell script-block logging (4104): the command line of the encoded stage showed only Base64, while 4104 showed the real payload. Without it, stage 2 would have been opaque.

## False Positive Considerations

- A single `net user` or one Run-key write is ordinary and would not be escalated. The weight here comes from the **sequence** and the shared parent process.
- Earlier in the same archive, `net user` ran twice as `DESKTOP-3UDQ08I$` (the SYSTEM/computer account) at 17:50. The burst rule correctly did **not** group these with the attacker's commands, because it keys on `subjectUserName`. This is the kind of benign activity a naive per-command rule would alert on.

## Recommended Response

- **Containment:** isolate the host; suspend `labuser` pending review.
- **Eradication:** remove the Run value `SF-INC-001`, delete the scheduled task `SF-INC-001`, delete the marker file. ([`INC-001-cleanup.ps1`](../../attacks/attack-scenarios/INC-001-cleanup.ps1) does this in the lab.)
- **Recovery:** confirm no payload executed. Both persistence entries point at `C:\ProgramData\SF-INC-001\does-not-exist.exe`, which is absent, so nothing has run from them.
- **Detection improvement:** consider a higher-severity correlation that fires when discovery, encoded execution and persistence occur under one process tree within a short window (chains the existing 1001xx rules).

## Lessons Learned

- Pivoting from one high-severity alert to the parent process reconstructed the whole intrusion; the single most useful field was the process/parent PID chain.
- Script-block logging (4104) is what defeats `-EncodedCommand`; command-line logging alone is not enough.
- Follow-on service activity (Task Scheduler via `svchost`) can post-date the attacker's action by minutes and shift when a persistence alert appears — worth noting so the timeline isn't misread.
