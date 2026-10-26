# INC-002: Account Discovery Commands by the SYSTEM Account

| Field | Value |
|---|---|
| **Incident ID** | INC-002 |
| **Title** | `net user` run as the computer account on DESKTOP-3UDQ08I |
| **Date** | 2026-10-26 |
| **Severity** | Informational |
| **MITRE ATT&CK Technique** | T1087.001: Account Discovery: Local Account (apparent) |
| **Status** | Closed |
| **Analyst** | Ericsung20 |

## Summary

While reviewing the account-discovery detections for [INC-001](../INC-001/README.md), two `net user` commands appeared at 17:50, four minutes before the real intrusion, run by `DESKTOP-3UDQ08I$` rather than a person. Investigation shows these were issued by the Wazuh agent itself as part of its routine inventory collection, running as SYSTEM. This is a **false positive** at the per-command level and was correctly **not** escalated by the burst correlation rule. The report documents the reasoning so the pattern is recognised next time.

## Alert

| Field | Value |
|---|---|
| Rule ID / name | 100140 — Account discovery command |
| Level | 3 |
| Timestamp (UTC) | 2026-10-26 17:50:36 (two events, 0.05 s apart) |
| Host / agent | DESKTOP-3UDQ08I (agent 001) |

The level-10 burst rule (100141) did **not** fire for this activity. Its only alert today was at 17:55:42 for `labuser` (the INC-001 intrusion).

## Process

| Field | Value |
|---|---|
| **Process** | `C:\Windows\SysWOW64\net.exe` |
| **Parent Process** | `C:\Program Files (x86)\ossec-agent\wazuh-agent.exe` |
| **Command Line** | `net user` |
| **User** | `DESKTOP-3UDQ08I$` (SID **S-1-5-18**, the SYSTEM / computer account) |
| Integrity level | `S-1-16-16384` (System) |
| Event record | Security 4688, EventRecordID 11511 |

Full export: [`evidence/system-net-user.txt`](evidence/system-net-user.txt).

## Related Events

| Time (UTC) | Source | Event | Detail |
|---|---|---|---|
| 17:50:36.594 | Security 4688 | `net.exe` ← `wazuh-agent.exe` | `net user`, subject `DESKTOP-3UDQ08I$` |
| 17:50:36.646 | Security 4688 | `net.exe` ← `wazuh-agent.exe` | `net user`, second run 0.05 s later |

No other discovery commands, no persistence, no file or registry writes are associated with these events or with the `wazuh-agent.exe` parent around this time.

## Timeline

| Time (UTC) | Event |
|---|---|
| 17:50:36.594 | `wazuh-agent.exe` runs `net user` as SYSTEM (100140, level 3) |
| 17:50:36.646 | a second `net user` as SYSTEM (100140, level 3) |
| — | burst rule 100141 does **not** fire (threshold is 3 within 60 s, per user) |
| 17:55:42 | unrelated: `labuser` begins the real intrusion ([INC-001](../INC-001/README.md)) |

## Analyst Assessment

**Benign — false positive at the per-command level.** Three independent signals agree:

1. **Subject is the computer account.** `DESKTOP-3UDQ08I$` with SID `S-1-5-18` is SYSTEM, not an interactive user. A human attacker normally operates under a user context.
2. **Parent is the monitoring agent.** The `net user` process was spawned by `wazuh-agent.exe`. Wazuh's Syscollector module enumerates local users as part of inventory, which is exactly `net user`. The security tool is observing its own activity.
3. **No surrounding malicious context.** There is no chain of discovery commands, no execution, no persistence — unlike INC-001, where the same rule sat inside a dense 90-second sequence.

The detection behaved correctly: rule 100140 (level 3) is an intentionally low-severity building block, and the correlation rule 100141 did not escalate it, because it counts per `subjectUserName` and SYSTEM only reached two events.

## False Positive Considerations

This *is* the false-positive case, so the question is the reverse: could a real attacker hide here? An attacker running as SYSTEM (after privilege escalation) could in principle issue `net user`. What rules this out:

- The parent process is specifically `wazuh-agent.exe`, the known inventory source, not a shell or an unknown binary.
- The two events are 50 ms apart and isolated, matching an automated poll, not interactive typing.

If SYSTEM-context discovery is a concern, the better control is parent-process allowlisting rather than alerting on every SYSTEM `net user`.

## Recommended Response

- **Containment / Eradication / Recovery:** none required; no malicious activity.
- **Detection improvement:** optionally exclude `wazuh-agent.exe` as a parent from rule 100140, or add a note that SYSTEM-context discovery from the agent is expected. Keeping 100140 at level 3 (informational) already prevents noise; no change is strictly needed.

## Lessons Learned

- The subject SID and the parent process together settle most "is this an attacker?" questions. `S-1-5-18` plus a known agent parent is benign.
- A monitoring agent generates telemetry that looks like the activity it hunts for. Recognising the agent's own inventory behaviour avoids chasing it.
- This is why the account-discovery detection was built as a correlation (100141) on top of a low-severity base rule (100140), not as a single high-severity alert: the base rule can be noisy on purpose, and the correlation is what an analyst should react to.
