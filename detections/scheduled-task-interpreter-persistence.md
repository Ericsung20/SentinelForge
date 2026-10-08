# Detection: Scheduled Task Runs a Script Interpreter at Boot or Logon

| Field | Value |
|---|---|
| **Rule Name** | Scheduled task runs a script interpreter at boot or logon |
| **Status** | Completed |
| **MITRE ATT&CK Technique** | T1053.005: Scheduled Task/Job: Scheduled Task |
| **Wazuh Rule ID** | 100120 (level 10), child of built-in 60228 |
| **Sigma Rule** | Not written yet |
| **Author** | Ericsung20 |
| **Created / Updated** | 2026-10-07 / 2026-10-07 |

## Description

A scheduled task that starts at boot or at logon is one of the most common ways to keep malware running across reboots. When the task launches a script interpreter (`cmd`, `powershell`, `wscript`, `mshta`, `rundll32` and similar) instead of a normal program, it usually means a script or one-liner is doing the real work, which is what attackers do.

Creating a scheduled task is also routine: installers and updaters do it all the time. The built-in rule 60228 therefore rates every task creation (Security 4698) at level 4. This rule raises only the combination that matters for persistence: **a boot or logon trigger and a script interpreter as the command**.

## Data Source

- Log channel: `Security`
- Event ID(s): 4698 (A scheduled task was created)
- Required config: *Other Object Access Events* auditing, from [`Set-AuditPolicy.ps1`](../telemetry/windows-events/Set-AuditPolicy.ps1)

The whole task definition (triggers, account, command) is in `win.eventdata.taskContent` as XML. Wazuh stores it **HTML-escaped**: `&lt;Command&gt;cmd.exe&lt;/Command&gt;`.

## Sample Telemetry

Task XML from the OnStartup test task (unescaped, trimmed):

```xml
<Triggers>
  <BootTrigger><Enabled>true</Enabled></BootTrigger>
</Triggers>
<Principals>
  <Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>LeastPrivilege</RunLevel></Principal>
</Principals>
<Actions Context="Author">
  <Exec><Command>cmd.exe</Command><Arguments>/c calc.exe</Arguments></Exec>
</Actions>
```

`S-1-5-18` is the SYSTEM account: the task runs with full privileges at every boot.

Alerts from the test on 2026-10-08 (UTC):

```text
05:23:40  rule 100120  level 10  Scheduled task \T1053_005_OnLogon runs a script interpreter at boot or logon (created by labuser)    T1053.005
05:23:41  rule 100120  level 10  Scheduled task \T1053_005_OnStartup runs a script interpreter at boot or logon (created by labuser)  T1053.005
```

## Detection Logic

- The event already matched built-in rule 60228 (Security 4698).
- The task XML has a `BootTrigger` or `LogonTrigger`.
- Its `<Command>` is one of `cmd`, `powershell`, `pwsh`, `wscript`, `cscript`, `mshta`, `rundll32`, `regsvr32`, with or without `.exe` or a path.

Rule ([`wazuh/sentinelforge_rules.xml`](wazuh/sentinelforge_rules.xml)):

```xml
<rule id="100120" level="10">
  <if_sid>60228</if_sid>
  <field name="win.eventdata.taskContent" type="pcre2">(?i)^(?=.*(Boot|Logon)Trigger)(?=.*Command.gt;[^;]*\b(cmd|powershell|pwsh|wscript|cscript|mshta|rundll32|regsvr32)(\.exe)?.lt;/Command)</field>
  <description>Scheduled task $(win.eventdata.taskName) runs a script interpreter at boot or logon (created by $(win.eventdata.subjectUserName))</description>
  <mitre>
    <id>T1053.005</id>
  </mitre>
  <group>windows,scheduled_task,persistence,</group>
</rule>
```

Why the pattern looks odd: the data contains `&gt;` and `&lt;`, but `&` and `<` are special characters inside the rule's own XML file. The pattern avoids both and uses `.gt;` and `.lt;` (`.` matches the `&`). `[^;]*` allows a path before the program name without running past the closing tag.

## False Positives

- Software that registers a logon task running a `.cmd` or PowerShell script (some backup, VPN and OEM tools).
- Admin-made startup scripts.
- In the lab only **2** task creations exist in the archive so far, both from this test, so the false-positive rate is untested on a busy machine. Expect to add an allowlist on task name or author.

## Known Gaps

- Tasks with time-based triggers (daily, every 5 minutes) don't match. They are a common persistence choice too, but far noisier.
- A task that runs the attacker's own `.exe` directly isn't flagged. That needs path-based logic (for example user-writable folders like `AppData` or `Temp`).
- Tasks created by writing XML files or registry keys directly ("ghost tasks", Atomic T1053.005-10) may not produce 4698 at all.

## Testing Procedure

1. Open an elevated PowerShell on the lab VM and load Atomic Red Team ([setup](../attacks/atomic-red-team/README.md)).
2. Run: `Invoke-AtomicTest T1053.005 -TestNumbers 1`. It creates `T1053_005_OnLogon` (logon trigger) and `T1053_005_OnStartup` (boot trigger, SYSTEM), both running `cmd.exe /c calc.exe`.
3. Cleanup: `Invoke-AtomicTest T1053.005 -TestNumbers 1 -Cleanup`

## Expected Result

- Two alerts, rule 100120, level 10, MITRE T1053.005, one per task

## Actual Result

- Fired: **Yes**, twice, 2026-10-08 05:23 UTC
- The same test run 17 minutes earlier, before the rule existed, produced only rule 60228 at level 4 for both tasks

## Tuning Notes

| Date | Change | Reason | FP before → after |
|---|---|---|---|
| 2026-10-07 | Initial version | — | — |
