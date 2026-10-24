# Sigma Rules

[Sigma](https://sigmahq.io/) versions of the lab's Wazuh detections. Sigma is a SIEM-neutral rule format: the same YAML converts to Splunk, Elastic, Microsoft Sentinel and other query languages, so each detection is not tied to Wazuh.

| Sigma rule | Wazuh rule | Technique (ATT&CK v20) | Detection doc |
|---|---|---|---|
| [`defender_exclusion_added.yml`](defender_exclusion_added.yml) | 100100 | T1685 | [Defender exclusion added](../defender-exclusion-added.md) |
| [`powershell_base64_iex.yml`](powershell_base64_iex.yml) | 100110 | T1059.001, T1027 | [PowerShell Base64 + iex](../powershell-base64-iex.md) |
| [`scheduled_task_interpreter_boot_logon.yml`](scheduled_task_interpreter_boot_logon.yml) | 100120 | T1053.005 | [Scheduled task persistence](../scheduled-task-interpreter-persistence.md) |
| [`run_key_set_by_script_interpreter.yml`](run_key_set_by_script_interpreter.yml) | 100130 | T1547.001 | [Run key](../run-key-script-interpreter.md) |
| [`account_discovery_command.yml`](account_discovery_command.yml) | 100140 | T1087.001 | [Account discovery burst](../account-discovery-burst.md) |
| [`account_discovery_burst.yml`](account_discovery_burst.yml) (correlation) | 100141 | T1087.001 | same |

## Validate and convert

From the repo root, in WSL:

```bash
python3 -m venv .venv && .venv/bin/pip install -r detections/sigma/requirements.txt
.venv/bin/sigma check detections/sigma/
.venv/bin/sigma convert -t splunk -p splunk_windows -o detections/sigma/converted/splunk.spl detections/sigma/
```

Result on 2026-10-23: **0 errors, 0 condition errors, 0 issues**. The Splunk output is committed in [`converted/splunk.spl`](converted/splunk.spl).

These rules are validated for syntax and conversion only. They have not been run against Splunk; the Wazuh rules are the ones tested live.

## Differences from the Wazuh rules

- **Field names.** Sigma uses the original Windows field names (`CommandLine`, `NewValue`, `TaskContent`) and leaves mapping to the target SIEM. The Wazuh rules use Wazuh's decoded names (`win.eventdata.commandLine`, ...).
- **Raw values.** Wazuh stores backslashes doubled and task XML HTML-escaped (`&lt;Command&gt;`), so the Wazuh patterns work around that. Sigma describes the original event, so the patterns use plain `\` and `<Command>`.
- **MITRE ATT&CK version.** `sigma check` validates tags against the current ATT&CK data (v20), where *Defense Evasion* was split into **Stealth** (TA0005) and **Defense Impairment** (TA0112), and *T1562.001 Disable or Modify Tools* became **T1685**. The Sigma rules use the v20 tags. The Wazuh rules keep T1562.001, because Wazuh 4.14.8 ships its own, older ATT&CK data.
- **Correlation window.** Wazuh's `frequency`/`timeframe` counts over a sliding 60-second window. The Splunk conversion of `account_discovery_burst.yml` uses `bin _time span=60s`, which counts in fixed 60-second buckets, so a burst that crosses a bucket boundary can be missed. For a sliding window in Splunk, rewrite it with `streamstats time_window=60s`.
- **Process creation source.** Sigma's `process_creation` category covers both Sysmon Event 1 and Security 4688; the Wazuh rules 100110 and 100140 use 4688 only.
