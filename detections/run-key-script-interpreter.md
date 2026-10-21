# Detection: Run Key Set by a Script Interpreter

| Field | Value |
|---|---|
| **Rule Name** | Run key set by script interpreter |
| **Status** | Completed |
| **MITRE ATT&CK Technique** | T1547.001: Boot or Logon Autostart Execution: Registry Run Keys / Startup Folder |
| **Wazuh Rule ID** | 100130 (level 10), child of built-in 92300 |
| **Sigma Rule** | Not written yet |
| **Author** | Ericsung20 |
| **Created / Updated** | 2026-10-21 / 2026-10-21 |

## Description

A value under `...\CurrentVersion\Run` (or `RunOnce`) is started every time the user logs on. It needs no admin rights for the user's own hive (HKCU), which makes it one of the simplest and most common persistence methods.

Wazuh's built-in rules cover this only partly:

| Built-in rule | Level | Matches |
|---|---|---|
| 92300 | 0 (no alert) | Any write to a Run key |
| 92301 | high | The value has a suspicious file extension |
| 92302 | 6 | The writer is `reg.exe` |
| 92303 | high | The value points to a remote access tool |

**The gap:** the same Run-key value written with PowerShell instead of `reg.exe` matches only 92300, so no alert is raised at all. Attackers set registry values from PowerShell far more often than with `reg.exe`.

## How the Gap Was Found

The two writes differ only in the program that made them:

| Writer | Command | Sysmon 13 logged | Wazuh alert |
|---|---|---|---|
| `reg.exe` | Atomic T1547.001-1 (`REG ADD ... /V "Atomic Red Team" /D C:\Path\AtomicRedTeam.exe`) | Yes | 92302, level 6 |
| `powershell.exe` | `Set-ItemProperty -Path HKCU:\...\Run -Name SentinelForgeTest -Value C:\Path\AtomicRedTeam.exe` | Yes | **None** |

The PowerShell write was a hand-made equivalent of the Atomic test. Atomic T1547.001-3 also uses PowerShell, but its value downloads and runs a script from the internet at next logon, and the extra keywords (`IEX`, `DownloadString`, `.bat`) would hit other rules and blur the result. Changing only the writer isolates the one thing being tested.

## Data Source

- Log channel: `Microsoft-Windows-Sysmon/Operational`
- Event ID(s): 13 (Registry value set)
- Required config: the [Sysmon config](../telemetry/sysmon/README.md) logs `\CurrentVersion\Run` writes (`technique_id=T1547.001` include rule)

## Sample Telemetry

Sysmon 13 from the `reg.exe` run (eventdata):

```text
ruleName     = technique_id=T1547.001,technique_name=Registry Run Keys / Startup Folder
eventType    = SetValue
image        = C:\WINDOWS\system32\reg.exe
targetObject = HKU\S-1-5-21-...-1001\Software\Microsoft\Windows\CurrentVersion\Run\Atomic Red Team
details      = C:\Path\AtomicRedTeam.exe
user         = DESKTOP-3UDQ08I\labuser
```

The PowerShell write has the same fields with `image = ...\WindowsPowerShell\v1.0\powershell.exe`.

Alert after the rule was deployed (2026-10-21, UTC):

```text
18:36:51  rule 100130  level 10  Run key HKU\S-1-5-21-...-1001\Software\Microsoft\Windows\CurrentVersion\Run\SentinelForgeTest set by script interpreter C:\...\powershell.exe: C:\Path\AtomicRedTeam.exe  T1547.001
```

## Detection Logic

- The event already matched built-in rule 92300 (a Sysmon 13 write under `CurrentVersion\Run` or `RunOnce`).
- The writing process is `powershell`, `pwsh`, `wscript`, `cscript`, `mshta` or `rundll32`.

Rule ([`wazuh/sentinelforge_rules.xml`](wazuh/sentinelforge_rules.xml)):

```xml
<rule id="100130" level="10">
  <if_sid>92300</if_sid>
  <field name="win.eventdata.image" type="pcre2">(?i)\\(powershell|pwsh|wscript|cscript|mshta|rundll32)\.exe$</field>
  <description>Run key $(win.eventdata.targetObject) set by script interpreter $(win.eventdata.image): $(win.eventdata.details)</description>
  <mitre>
    <id>T1547.001</id>
  </mitre>
  <group>windows,registry,persistence,</group>
</rule>
```

## False Positives

- Admin or deployment scripts that register startup programs with PowerShell.
- Installers that use script hosts to write their own Run entries.
- Archive baseline: only **3** Run-key writes exist so far, all from these tests (2 PowerShell, 1 `reg.exe`). The rate on a real workstation is untested; an allowlist on `details` (known program paths) would be the first tuning step.

Also observed: the `reg.exe` run fired built-in rule **92041** at level 10 ("Value added to registry key has Base64-like pattern") although `C:\Path\AtomicRedTeam.exe` is not Base64. That built-in rule is a false positive here.

## Known Gaps

- Writers not in the list (a compiled `.exe` dropped by the attacker, `regedit`, WMI's `WmiPrvSE.exe`) are not flagged. A complementary rule could look at `details` instead, for example values pointing into `AppData`, `Temp` or `Users\Public`.
- Other autostart locations (Startup folder, `Winlogon\Userinit`, `Explorer\Run` policy keys) are not covered by 92300 and therefore not by this rule.
- Only Run keys that the Sysmon config logs are visible. Keys outside its include rules produce no event.

## Testing Procedure

On the lab VM, in PowerShell (no admin needed):

```powershell
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -Name SentinelForgeTest -Value C:\Path\AtomicRedTeam.exe
```

Cleanup:

```powershell
Remove-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -Name SentinelForgeTest
```

The value points to a file that doesn't exist, so the next logon only fails to start it.

## Expected Result

- Rule 100130, level 10, MITRE T1547.001

## Actual Result

- Fired: **Yes**, 2026-10-21 18:36:51 UTC
- The identical write 3 minutes earlier, before the rule existed, produced no alert (rule 92300, level 0)

## Tuning Notes

| Date | Change | Reason | FP before → after |
|---|---|---|---|
| 2026-10-21 | Initial version | — | — |
