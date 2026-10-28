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

## Analyst Assessment

**True positive.** The evidence shows a classic persistence install:

1. **Persistence intent.** The task fires on a `LogonTrigger`, so it re-executes the payload every
   time the user logs on — the defining characteristic of T1053.005, not a one-off action.
2. **Interpreter payload.** The action launches `powershell.exe -ExecutionPolicy Bypass -WindowStyle
   Hidden` against a dropped script — bypassing policy and hiding the window, both attacker hallmarks.
3. **Administrative context.** Creation succeeded only from a Full (elevated) token; non-elevated
   attempts were denied. An intruder reaching this point already holds admin on the host.

The chain is intact end to end: dropped payload → elevated `powershell` → `schtasks /create` →
Schedule service registers the task on disk → 4698 → alert. Nothing about it resembles routine admin
housekeeping (see below).

## False Positive Considerations

Legitimate software and administrators do create logon-triggered tasks (updaters, agent bootstraps,
login scripts). What rules that out here:

- **Author and location.** The task was authored interactively by `labuser` and runs a script from
  `C:\ProgramData\SF-INC-003\`, not a vendor install path. A legitimate installer runs as SYSTEM or a
  service account via an MSI, not from an ad-hoc admin console.
- **Payload shape.** `-ExecutionPolicy Bypass -WindowStyle Hidden -File <dropped script>` is the
  signature of hands-on-keyboard persistence, not a signed updater.
- **No change ticket / known software.** There is no corresponding install event or known-good task
  name. Contrast with INC-002, where the subject SID (SYSTEM) and parent (`wazuh-agent.exe`) explained
  the activity; here the context *confirms* rather than exonerates.

If a specific legitimate logon task were expected, the right tuning is an allowlist of known task
names / authors, not suppressing 100120 wholesale.

## Recommended Response

- **Containment:** disable the task immediately — `schtasks /change /tn SF-INC-003 /disable` (or
  `Disable-ScheduledTask`), and isolate the host if other indicators exist.
- **Eradication:** delete the task and the staged payload — run
  [`attacks/attack-scenarios/INC-003-cleanup.ps1`](../../attacks/attack-scenarios/INC-003-cleanup.ps1)
  (removes `\SF-INC-003`, `C:\ProgramData\SF-INC-003\`, and the marker file).
- **Recovery:** confirm no logon has executed the payload (check for the marker / `payload.ps1`
  output) and review how the admin token was obtained.
- **Detection improvement:** 100120 already covers boot/logon tasks launching interpreters. Consider a
  companion rule for `schtasks /create` seen directly in 4688 command lines, to catch creation even
  when 4698 auditing is disabled.

## Lessons Learned

- The task-creation event (4698) carries the **full task XML**, so the trigger, the exact action, and
  the principal are all available from a single event — no need to pull the task file off the host.
- **Token elevation type is decisive.** `%%1937` (Full) vs `%%1938` (Limited) separated the real,
  successful install from the earlier failed non-elevated attempts, and confirms the attacker held admin.
- Detecting on **task creation** beats detecting on execution: the alert fires the moment persistence
  is planted, long before the next logon would run the payload.
- Contrast across the three Phase 5 cases: INC-001 (multi-stage, true positive), INC-002 (SYSTEM
  inventory, benign false positive), INC-003 (single-technique persistence, true positive) — the same
  rule family reads very differently depending on subject SID, parent process, and elevation.
