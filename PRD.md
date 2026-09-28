# SentinelForge: Product Requirements

## Primary Goal

Develop the ability to **observe adversary behavior, understand the telemetry it generates, write detection logic, investigate alerts and document findings.**

Success is measured by documented, reproducible end-to-end chains, not by the number of tools installed.

## Target User

Me. The lab builds practical detection engineering and SOC analyst skills, plus a portfolio that demonstrates them.

## MVP (v1) Scope

| # | Requirement | Done when |
|---|---|---|
| 1 | 1 Windows endpoint | The endpoint is available and isolated for lab use |
| 2 | Sysmon configured | Sysmon runs with a documented config and its events show in Event Viewer |
| 3 | Wazuh operational | Manager, Indexer and Dashboard run in Docker and the dashboard is reachable |
| 4 | Windows logs ingested | Sysmon and Security events from the endpoint are searchable in Wazuh |
| 5 | 5 ATT&CK techniques simulated | Each simulation is documented under `attacks/` with its technique ID |
| 6 | 5 custom detections | Each rule is documented per `detections/TEMPLATE.md` |
| 7 | 5 successful alerts | Each detection fires on its simulation and the evidence is captured |
| 8 | 3 detailed investigations | Each has analyst-style triage and a timeline under `investigations/` |
| 9 | 3 incident reports | Each follows `investigations/_TEMPLATE/README.md` |
| 10 | GitHub documentation | README, setup, architecture and detection docs match reality |

## Principles

- **Telemetry first.** Look at the raw events before writing a rule.
- **Traceability.** Every artifact links back to an ATT&CK technique ID.
- **Honest status.** Planned, In Progress or Completed, never overstated.
- **Reproducible.** Someone else could rebuild the lab from `docs/setup.md`.
- **Safe.** Only established test frameworks, only in the lab.

## Non-Goals (v1)

- Malware development
- Exploit development
- Full enterprise SOC
- Large endpoint deployment
- Custom SIEM development
- Full EDR development
- Machine-learning IDS
- Kubernetes security platform

## Constraints

- Runs on a single workstation: Windows 11, WSL2 (Ubuntu), Docker Desktop, 32 GB RAM
- No secrets, credentials, certificates or private config committed to Git
- Raw evidence (`.evtx`, `.pcap`, memory dumps) stays local; only redacted excerpts go in the repo

## Risks

| Risk | Mitigation |
|---|---|
| The Wazuh stack uses a lot of resources on a single host | Use a single-node deployment and cap container memory |
| Atomic tests change the endpoint's state | Use a dedicated VM with snapshots and run the cleanup commands |
| Sensitive data gets committed | `.gitignore` covers secrets, certificates and raw evidence; review diffs before each commit |
| Scope creep | Hold to the MVP and park extra ideas under "Later" in the roadmap |
