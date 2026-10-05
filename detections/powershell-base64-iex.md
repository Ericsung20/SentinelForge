# Detection: PowerShell Decodes Base64 and Executes It

| Field | Value |
|---|---|
| **Rule Name** | PowerShell decoded Base64 and executed it in memory |
| **Status** | Completed |
| **MITRE ATT&CK Technique** | T1059.001: PowerShell; T1027: Obfuscated Files or Information |
| **Wazuh Rule ID** | 100110 (level 10), child of built-in 67027 |
| **Sigma Rule** | Not written yet |
| **Author** | Ericsung20 |
| **Created / Updated** | 2026-10-05 / 2026-10-05 |

## Description

Malware that wants to stay off disk often stores a PowerShell script as Base64 (in the registry, a variable or the command line itself), then decodes it and passes the result straight to `Invoke-Expression` (`iex`). Nothing readable is written to disk, and the command line shows only the decoding wrapper. The Poweliks and Powessere families work this way.

Decoding Base64 and calling `iex` both have legitimate uses on their own. Doing both in the command line that starts PowerShell is rare in normal administration and common in malicious loaders.

Before this rule, the process creation behind the test matched only built-in rule 67027 ("A process was created.", level 3), the same as every other process on the machine.

## Data Source

- Log channel: `Security`
- Event ID(s): 4688 (A new process has been created)
- Required config: Process Creation auditing with command-line capture, from [`Set-AuditPolicy.ps1`](../telemetry/windows-events/Set-AuditPolicy.ps1). Without `ProcessCreationIncludeCmdLine_Enabled`, 4688 has no command line and this rule cannot match.

Sysmon did not record an Event ID 1 for this process in the lab. The reason is not confirmed yet, so 4688 is the source the rule relies on.

## Sample Telemetry

The alert from the test on 2026-10-05 (system fields trimmed, command line shortened):

```json
{
  "timestamp": "2026-10-05T17:52:20.172+0000",
  "rule": {
    "level": 10,
    "description": "PowerShell decoded Base64 and executed it in memory (user labuser)",
    "id": "100110",
    "mitre": {
      "id": ["T1059.001", "T1027"],
      "tactic": ["Execution", "Defense Evasion"],
      "technique": ["PowerShell", "Obfuscated Files or Information"]
    },
    "groups": ["sentinelforge", "windows", "powershell", "execution", "defense_evasion"]
  },
  "agent": { "id": "001", "name": "DESKTOP-3UDQ08I", "ip": "10.0.2.15" },
  "data": {
    "win": {
      "system": { "eventID": "4688", "channel": "Security", "eventRecordID": "5262" },
      "eventdata": {
        "subjectUserName": "labuser",
        "newProcessName": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
        "parentProcessName": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
        "commandLine": "\"powershell.exe\" & {# Encoded payload in next command is the following ... reg.exe add ... iex ([Text.Encoding]::ASCII.GetString([Convert]::FromBase64String(...)))}"
      }
    }
  }
}
```

## Detection Logic

- The event already matched built-in rule 67027 (Security 4688).
- The new process is `powershell.exe` or `pwsh.exe`.
- Its command line contains **both** `FromBase64String` **and** `iex` or `Invoke-Expression`, in any order and any case.

Rule ([`wazuh/sentinelforge_rules.xml`](wazuh/sentinelforge_rules.xml)):

```xml
<rule id="100110" level="10">
  <if_sid>67027</if_sid>
  <field name="win.eventdata.newProcessName" type="pcre2">(?i)\\(powershell|pwsh)\.exe$</field>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)^(?=.*FromBase64String)(?=.*(\biex\b|Invoke-Expression))</field>
  <description>PowerShell decoded Base64 and executed it in memory (user $(win.eventdata.subjectUserName))</description>
  <mitre>
    <id>T1059.001</id>
    <id>T1027</id>
  </mitre>
  <group>windows,powershell,execution,defense_evasion,</group>
</rule>
```

The two lookaheads require both words without fixing their order.

## False Positives

- Admin or deployment scripts that pass a Base64 blob to `iex` on the command line. Uncommon, but it happens in some management tools.
- Checked against everything archived so far: of **903** Security 4688 events, only the **2** test runs contained `FromBase64String`. No false positives in the lab.

## Known Gaps

- `powershell -EncodedCommand <base64>` hides the whole script in Base64, so neither keyword appears in the command line. That variant needs its own rule (or 4104 script block logging, which records the decoded text).
- Obfuscated keywords (string concatenation, backticks, `Get-Alias` tricks) would evade the literal match.
- Only process creation is checked. The same decode-and-run inside an already running PowerShell session produces no new 4688. Script block logging (4104) covers that case.

## Testing Procedure

1. Start from snapshot `07-atomic-red-team` and open an elevated PowerShell with `Set-ExecutionPolicy Bypass -Scope Process -Force` ([setup](../attacks/atomic-red-team/README.md)).
2. Run the test: `Invoke-AtomicTest T1059.001 -TestNumbers 10`
3. Run the cleanup: `Invoke-AtomicTest T1059.001 -TestNumbers 10 -Cleanup`

Defender blocks the test (`Access is denied` in the console, Defender 1116 `Trojan:Win32/Powessere.K`). That's fine: the command line is still logged, and the rule doesn't depend on the payload running.

## Expected Result

- Rule 100110, level 10, MITRE T1059.001 and T1027
- Defender alert rule 62123, level 12, about a second later

## Actual Result

- Fired: **Yes**, 2026-10-05 17:52:20 UTC, on the first test after deployment
- The same test run 8 minutes earlier, before the rule existed, produced only rule 67027 at level 3
- Our alert came one second before Defender's own alert (rule 62123, level 12), showing the SIEM detects it independently of the antivirus

## Tuning Notes

| Date | Change | Reason | FP before → after |
|---|---|---|---|
| 2026-10-05 | Initial version | — | — |
