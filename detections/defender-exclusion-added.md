# Detection: Windows Defender Exclusion Added

| Field | Value |
|---|---|
| **Rule Name** | Windows Defender exclusion added |
| **Status** | Completed |
| **MITRE ATT&CK Technique** | T1562.001: Impair Defenses: Disable or Modify Tools |
| **Wazuh Rule ID** | 100100 (level 10), child of built-in 62154 |
| **Sigma Rule** | Not written yet |
| **Author** | Ericsung20 |
| **Created / Updated** | 2026-10-04 / 2026-10-04 |

## Description

Adding a Defender exclusion (a folder, file extension, process or IP) stops Defender from scanning it. Attackers do this to drop and run tools without being blocked, and it is quieter than turning Defender off.

Wazuh does see the change, as Defender event 5007, but its built-in rule 62154 rates every 5007 at level 5. The same rule and level cover Defender's routine internal updates such as `CoreService\WdConfigHash`, so an exclusion added by an attacker looks like background noise. This rule singles it out.

**How the gap was found:** an exclusion added from the Windows Security UI produced nothing in Wazuh, not even in the full event archive. The command-line rule 92007 needs `Set-MpPreference` in a PowerShell command line, the UI writes the registry through Defender's own service, and the Defender log was not being collected. Collecting `Microsoft-Windows-Windows Defender/Operational` made the event visible. This rule makes it stand out.

## Data Source

- Log channel: `Microsoft-Windows-Windows Defender/Operational`
- Event ID(s): 5007 (Antimalware platform configuration changed)
- Required config: the channel in [`agent.conf`](../infrastructure/wazuh/shared/default/agent.conf). No audit policy or Sysmon rule is needed.

## Sample Telemetry

The alert from the test on 2026-10-04 (system fields trimmed):

```json
{
  "timestamp": "2026-10-05T03:02:09.439+0000",
  "rule": {
    "level": 10,
    "description": "Windows Defender exclusion added: HKLM\\SOFTWARE\\Microsoft\\Windows Defender\\Exclusions\\Paths\\C:\\AtomicRedTeam = 0x0",
    "id": "100100",
    "mitre": { "id": ["T1562.001"], "tactic": ["Defense Evasion"], "technique": ["Disable or Modify Tools"] },
    "groups": ["sentinelforge", "windows", "windows_defender", "defense_evasion"]
  },
  "agent": { "id": "001", "name": "DESKTOP-3UDQ08I", "ip": "10.0.2.15" },
  "data": {
    "win": {
      "system": { "eventID": "5007", "channel": "Microsoft-Windows-Windows Defender/Operational", "eventRecordID": "435" },
      "eventdata": {
        "product Name": "Microsoft Defender Antivirus",
        "new Value": "HKLM\\SOFTWARE\\Microsoft\\Windows Defender\\Exclusions\\Paths\\C:\\AtomicRedTeam = 0x0"
      }
    }
  }
}
```

## Detection Logic

- The event already matched built-in rule 62154 (Defender event 5007).
- Its `new Value` is a registry path under `Windows Defender\Exclusions\Paths`, `Extensions`, `Processes` or `IpAddresses`.
- An exclusion being *removed* leaves `new Value` empty and puts the path in `old Value`, so it does not match.

Rule ([`wazuh/sentinelforge_rules.xml`](wazuh/sentinelforge_rules.xml)):

```xml
<rule id="100100" level="10">
  <if_sid>62154</if_sid>
  <field name="win.eventdata.new Value" type="pcre2">(?i)Windows Defender\\+Exclusions\\+(Paths|Extensions|Processes|IpAddresses)\\+</field>
  <description>Windows Defender exclusion added: $(win.eventdata.new Value)</description>
  <mitre>
    <id>T1562.001</id>
  </mitre>
  <group>windows,windows_defender,defense_evasion,</group>
</rule>
```

Wazuh stores the path with escaped (doubled) backslashes, so the pattern uses `\\+`. The field name contains a space (`new Value`), and Wazuh accepts it as written.

## False Positives

- Administrators adding exclusions on purpose, for example for build folders, databases or backup software.
- Software installers that add their own exclusions.

In this lab every exclusion is worth a look. In a real environment, add known-good paths as an allowlist (see Tuning Notes).

## Testing Procedure

1. Revert the endpoint to a clean snapshot, or note the current exclusions.
2. Make sure the Wazuh stack is running and the agent is Active.
3. Add an exclusion: **Windows Security → Virus & threat protection → Manage settings → Exclusions → Add an exclusion → Folder**.
4. Cleanup: remove the exclusion from the same screen.

Not yet tested: adding the exclusion with `Add-MpPreference`. That path should also produce 5007, and additionally match built-in rule 92007 on the PowerShell command line.

## Expected Result

- Rule 100100, level 10, MITRE T1562.001
- `data.win.eventdata.new Value` shows the excluded path
- Removing the exclusion stays at rule 62154, level 5

## Actual Result

- Fired: **Yes**, 2026-10-04, on the first test after deployment
- Removal of the same exclusion 11 seconds earlier stayed at rule 62154, level 5, as expected
- Evidence: the alert above

## Tuning Notes

| Date | Change | Reason | FP before → after |
|---|---|---|---|
| 2026-10-04 | Initial version | — | — |
