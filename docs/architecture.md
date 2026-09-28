# Architecture

> **Status:** Planned. This describes the target design; nothing below is deployed yet.

## Data Flow

```
MITRE ATT&CK technique
        ↓
Atomic Red Team test
        ↓
Windows Endpoint
  • Sysmon (Microsoft-Windows-Sysmon/Operational)
  • Windows Event Logs (Security, System, PowerShell)
        ↓
Wazuh Agent (on the endpoint)
        ↓  TCP 1514 (events), 1515 (enrollment)
Wazuh Manager: decoders + rules (including detections/wazuh)
        ↓
Wazuh Indexer (OpenSearch-based storage)
        ↓
Wazuh Dashboard (search, alerts, visualization)
        ↓
Analyst: triage → investigation → incident report
```

## Components

| Component | Role | Runs on | Status |
|---|---|---|---|
| Windows endpoint | Target of the simulations; generates telemetry | Windows VM (preferred) or host | Planned |
| Sysmon | Detailed process, network, file and registry telemetry | Endpoint | Planned |
| Windows Event Logs | Security/auth, PowerShell script block and service events | Endpoint | Planned |
| Wazuh Agent | Collects and forwards event channels | Endpoint | Planned |
| Wazuh Manager | Decodes events, applies rules and raises alerts | Docker (WSL2) | Planned |
| Wazuh Indexer | Stores alerts and events | Docker (WSL2) | Planned |
| Wazuh Dashboard | UI for search and triage | Docker (WSL2) | Planned |
| Atomic Red Team | Controlled technique simulation | Endpoint | Planned |
| Python automation | Parses, enriches and reports on alerts | WSL2 | Planned |

## Key Telemetry Sources (initial)

| Source | Event IDs of interest | Why |
|---|---|---|
| Sysmon | 1 (process create), 3 (network), 7 (image load), 11 (file create), 13 (registry set), 22 (DNS) | Core behavioral visibility |
| Security | 4624/4625 (logon), 4688 (process create), 4698 (scheduled task), 4720 (account created) | Authentication and persistence |
| PowerShell | 4104 (script block logging) | Visibility into script content |

## Design Decisions

- **Single-node Wazuh in Docker.** It fits a 32 GB workstation and is enough for one to a few endpoints.
- **The endpoint is a VM with snapshots (preferred).** Simulations can be reverted cleanly without touching the daily-use host.
- **Rules as code.** Custom Wazuh rules and Sigma rules are versioned in `detections/`.

## Open Questions

- Windows endpoint: Hyper-V VM or another hypervisor (decide in Phase 1)
- Networking between the WSL2/Docker stack and the Windows VM (decide in Phase 1)
