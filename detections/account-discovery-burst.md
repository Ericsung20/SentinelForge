# Detection: Account Discovery Burst

| Field | Value |
|---|---|
| **Rule Name** | Account discovery burst |
| **Status** | Completed |
| **MITRE ATT&CK Technique** | T1087.001: Account Discovery: Local Account |
| **Wazuh Rule ID** | 100140 (level 3, per command) and 100141 (level 10, correlation) |
| **Sigma Rule** | Not written yet |
| **Author** | Ericsung20 |
| **Created / Updated** | 2026-10-22 / 2026-10-22 |

## Description

Right after getting a foothold, an attacker asks "which accounts exist here, who is an admin, and are any credentials saved?" The answers come from built-in tools: `net user`, `net localgroup`, `cmdkey /list`, `quser`, `whoami /all`.

Each of these is also something admins and Windows itself run. A rule that alerts on a single `net user` is mostly noise. What stands out is **several of them from the same user within seconds**, which is how a script or an attacker walks through a new machine.

This is the lab's first **correlation rule**: one rule tags each command at a low level, a second rule fires only when the tags pile up.

## Data Source

- Log channel: `Security`
- Event ID(s): 4688 (A new process has been created)
- Required config: Process Creation auditing with command-line capture, from [`Set-AuditPolicy.ps1`](../telemetry/windows-events/Set-AuditPolicy.ps1)

## What the Built-in Rules Did

Atomic T1087.001-8 ran five commands in about a second. The built-in rules saw each one separately:

| Command | Built-in rule | Level |
|---|---|---|
| `cmd.exe /c net user & dir c:\Users\ & cmdkey.exe /list & ...` | 92052 | 4 |
| `net user` | 92036, 92031 | 3 |
| `cmdkey.exe /list` | 92032 | 3 |
| `net localgroup "Users"` | 92036, 92031 | 3 |
| `net localgroup` | 92036, 92031 | 3 |

Nothing tied them together, and nothing rose above level 4.

## Detection Logic

**100140** (level 3), child of built-in 67027 (Security 4688): the command line is one of

- `net user|localgroup|group|accounts`
- `cmdkey /list`
- `quser` or `query user`
- `whoami` with `/all`, `/groups` or `/priv`

**100141** (level 10): 100140 matched **3 or more times within 60 seconds for the same `subjectUserName`**.

Rule ([`wazuh/sentinelforge_rules.xml`](wazuh/sentinelforge_rules.xml)):

```xml
<rule id="100140" level="3">
  <if_sid>67027</if_sid>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)(\bnet\s+(user|localgroup|group|accounts)\b|\bcmdkey(\.exe)?\s+/list|\bquser\b|\bquery\s+user\b|\bwhoami\b.*\s/(all|groups|priv))</field>
  <description>Account discovery command by $(win.eventdata.subjectUserName): $(win.eventdata.commandLine)</description>
  <mitre>
    <id>T1087.001</id>
  </mitre>
  <group>windows,discovery,</group>
</rule>

<rule id="100141" level="10" frequency="3" timeframe="60">
  <if_matched_sid>100140</if_matched_sid>
  <same_field>win.eventdata.subjectUserName</same_field>
  <description>Account discovery burst: 3 or more enumeration commands within 60 seconds by $(win.eventdata.subjectUserName)</description>
  <mitre>
    <id>T1087.001</id>
  </mitre>
  <group>windows,discovery,</group>
</rule>
```

Design choices:

- **`net1.exe` is not matched.** `net user` starts `net.exe`, which starts `net1.exe` with the same arguments. Matching both would count every command twice and fire on one and a half commands.
- **Plain `whoami` is not matched.** `Invoke-AtomicTest` runs `whoami` itself before every test, and on its own it says little. `whoami /all` (groups and privileges) is the recon variant.
- **`same_field` on the user** keeps unrelated activity from adding up. Windows' own background `net user` runs as the computer account and never mixes with a person's commands.

## Sample Telemetry

Alerts from the rerun on 2026-10-22 (UTC):

```text
16:21:49  rule 100140  level 3   Account discovery command by labuser: "cmd.exe" /c net user & dir c:\Users\ & cmdkey.exe /list & ...
16:21:49  rule 100140  level 3   Account discovery command by labuser: net  user
16:21:49  rule 100141  level 10  Account discovery burst: 3 or more enumeration commands within 60 seconds by labuser
16:21:49  rule 100140  level 3   Account discovery command by labuser: net  localgroup "Users"
16:21:49  rule 100140  level 3   Account discovery command by labuser: net  localgroup
```

The event that completes the count (here `cmdkey.exe /list`) is reported as 100141 rather than 100140, which is why it doesn't appear in the 100140 lines.

## False Positives

Replay of the 100141 logic over all **330** Security 4688 events currently in the archive:

- 12 commands matched 100140.
- 2 bursts would have fired, at 16:18:25 and 16:21:49, **both Atomic test runs**.
- Not a burst: 2 × `net user` at 16:13:23 run by `DESKTOP-3UDQ08I$` (the computer account, i.e. Windows itself). A per-command rule would have alerted on this; the burst rule correctly stays quiet.

Expected in real environments: admin troubleshooting sessions, inventory and IT-management scripts that enumerate local groups. Tune with an allowlist on user or parent process.

## Known Gaps

- **The `cmd.exe /c ...` wrapper counts too.** When several commands are chained in one `cmd /c` line, that parent line matches as well. Three matches can therefore come from two real commands plus the wrapper.
- `net1.exe` run directly (to dodge `net.exe` monitoring) is not counted.
- PowerShell equivalents (`Get-LocalUser`, `Get-LocalGroupMember`) start no new process and are invisible to 4688. They would need a 4104 script-block rule.
- A patient attacker spacing commands more than 60 seconds apart stays under the threshold.

## Testing Procedure

1. Open an elevated PowerShell on the lab VM and load Atomic Red Team ([setup](../attacks/atomic-red-team/README.md)).
2. Run: `Invoke-AtomicTest T1087.001 -TestNumbers 8`. It runs `net user`, `dir c:\Users\`, `cmdkey.exe /list`, `net localgroup "Users"` and `net localgroup`.
3. No cleanup needed: the commands only read information.

## Expected Result

- Four 100140 alerts (level 3) and one 100141 alert (level 10), MITRE T1087.001

## Actual Result

- Fired: **Yes**, 2026-10-22 16:21:49 UTC
- The same test 3 minutes earlier, before the rules existed, produced only separate level 3 and 4 alerts

## Tuning Notes

| Date | Change | Reason | FP before → after |
|---|---|---|---|
| 2026-10-22 | Initial version | — | — |
