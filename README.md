# SentinelForge

**A personal Detection Engineering and Mini-SOC lab.**

SentinelForge recreates the full defensive security workflow in a small, controlled lab. It simulates a known adversary technique, observes the telemetry that technique produces on a Windows endpoint, and ships that telemetry to a SIEM. From there it writes detection logic, triages the resulting alert and documents the investigation as an incident report.

> **Status:** Phase 3 complete. A Windows 11 lab VM sends Sysmon, Security, PowerShell and Defender events to a single-node Wazuh SIEM. The first custom rule, [Defender exclusion added](detections/defender-exclusion-added.md) (T1562.001), closes a gap the built-in rules missed and fires on a documented test. Next is Phase 4: more ATT&CK techniques. See [Current Project Status](#current-project-status).

---

## Motivation

Installing a SIEM is easy. The real skill is understanding *why* an alert fired, *what* the underlying telemetry looks like and *whether* the detection is any good.

This project exists to build hands-on experience with:

- Windows security telemetry (Sysmon, Windows Event Logs)
- SIEM workflows with Wazuh
- Writing and tuning detections (Wazuh custom rules, Sigma)
- Mapping behavior to MITRE ATT&CK
- Safe adversary emulation with Atomic Red Team
- Threat hunting, alert triage and incident investigation
- Python automation for repetitive analyst tasks

The goal isn't a tool collection. It is a documented, repeatable trail from **behavior → telemetry → detection → investigation**.

---

## Architecture Overview

```
           ┌───────────────────────────────┐
           │   MITRE ATT&CK technique      │
           │   (Atomic Red Team test)      │
           └──────────────┬────────────────┘
                          ▼
┌──────────────────────────────────────────────────────┐
│ Windows Endpoint                                     │
│   Sysmon  +  Windows Event Logs                      │
│   Wazuh Agent                                        │
└──────────────┬───────────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────────────┐
│ Wazuh Stack (Docker on WSL2)                         │
│   Wazuh Manager → Wazuh Indexer → Wazuh Dashboard    │
│   + custom rules (detections/wazuh)                  │
└──────────────┬───────────────────────────────────────┘
               ▼
        Alerts → Investigation → Incident Report
```

Detailed design: [docs/architecture.md](docs/architecture.md)

---

## Core Workflow

```
Attack → Telemetry → Detection → Alert → Investigation → Response
```

| Stage | What happens | Where it lives in this repo |
|---|---|---|
| Attack | Controlled simulation of an ATT&CK technique | `attacks/` |
| Telemetry | The endpoint generates Sysmon and Windows Event Log data | `telemetry/` |
| Detection | Wazuh rules and Sigma rules evaluate the telemetry | `detections/` |
| Alert | Wazuh raises an alert in the dashboard | Evidence and screenshots in `investigations/` |
| Investigation | Analyst-style triage, timeline and assessment | `investigations/INC-XXX/` |
| Response | Recommended containment and detection improvements | Incident report and tuning notes |

---

## Technology Stack

| Area | Technology | Status |
|---|---|---|
| Host OS | Windows 11 | Completed |
| Linux environment | WSL2 (Ubuntu) | Completed |
| Containers | Docker Desktop + WSL integration | Completed |
| Version control | Git / GitHub | Completed |
| Lab endpoint | VirtualBox VM, Windows 11 Enterprise Evaluation | Completed |
| Endpoint telemetry | Sysmon, Windows Event Logs (audit policy), PowerShell script block logging | Completed |
| SIEM | Wazuh 4.14.8 (Manager, Indexer, Dashboard, Agent) | Completed |
| Detection formats | Wazuh custom rules, Sigma | In Progress (first Wazuh rule; Sigma not started) |
| Framework | MITRE ATT&CK | Planned |
| Adversary emulation | Atomic Red Team | Planned |
| Automation | Python | Planned |

---

## Project Phases

| Phase | Name | Status |
|---|---|---|
| 0 | Development environment | **Completed** |
| 1 | Infrastructure (Windows → Sysmon → Wazuh Agent → Wazuh) | **Completed** |
| 2 | First observable security event | **Completed** |
| 3 | First detection | **Completed** |
| 4 | Detection engineering (5–10 ATT&CK techniques) | Planned |
| 5 | Investigation | Planned |
| 6 | Detection tuning | Planned |
| 7 | Automation (Python) | Planned |
| 8 | Portfolio polish | Planned |

Full plan: [ROADMAP.md](ROADMAP.md) · Requirements: [PRD.md](PRD.md)

---

## Repository Structure

```
SentinelForge/
├── README.md                 # This file
├── PRD.md                    # Goals, MVP scope, non-goals
├── ROADMAP.md                # Phase-by-phase plan
├── LEARNING_LOG.md           # Running build journal
├── LICENSE
├── .gitignore                # Excludes secrets, certificates and raw evidence
│
├── infrastructure/
│   ├── wazuh/                # Wazuh config (no certificates or secrets)
│   └── docker/               # Docker Compose for the lab stack
│
├── telemetry/
│   ├── sysmon/               # Sysmon configuration and notes
│   └── windows-events/       # Audit policy and Event ID reference notes
│
├── attacks/
│   ├── atomic-red-team/      # Which Atomic tests were run, and how
│   └── attack-scenarios/     # Multi-step scenarios chained from Atomics
│
├── detections/
│   ├── TEMPLATE.md           # Required documentation for every detection
│   ├── sigma/                # Sigma rules
│   └── wazuh/                # Wazuh custom rules
│
├── investigations/
│   └── _TEMPLATE/            # Copy to INC-XXX/ for each incident
│       ├── README.md
│       ├── evidence/
│       └── screenshots/
│
├── automation/               # Python analyst tooling
│
└── docs/
    ├── architecture.md
    ├── setup.md
    └── detection-engineering.md
```

---

## MITRE ATT&CK Integration

Every simulation, detection and investigation is tagged with an ATT&CK technique ID (for example `T1059.001`). The tags make it possible to:

- Trace a single technique from simulation → telemetry → rule → alert → report
- Measure detection coverage per tactic and technique
- Prioritize what to detect next

Candidate techniques for the MVP (subject to change as the lab takes shape):

| Technique | Name | Status |
|---|---|---|
| T1059.001 | Command and Scripting Interpreter: PowerShell | Planned |
| T1053.005 | Scheduled Task/Job: Scheduled Task | Planned |
| T1547.001 | Boot or Logon Autostart Execution: Registry Run Keys | Planned |
| T1087 | Account Discovery | Planned |
| T1105 | Ingress Tool Transfer | Planned |
| T1562.001 | Impair Defenses: Disable or Modify Tools | **Completed**: [Defender exclusion added](detections/defender-exclusion-added.md) (rule 100100) |

---

## Detection Engineering Goals

- Write detections from **observed telemetry**, not from guesswork
- Document every rule with its logic, data source, test procedure, and expected and actual results ([template](detections/TEMPLATE.md))
- Maintain both a Wazuh-native rule and a portable Sigma equivalent where practical
- Measure false positives deliberately, then tune and record the before and after
- Track coverage against ATT&CK

Process: [docs/detection-engineering.md](docs/detection-engineering.md)

---

## Planned Incident Investigation Workflow

1. **Alert received**: capture the Wazuh alert (rule ID, level, timestamp, host)
2. **Scope**: identify the process, parent process, command line and user
3. **Pivot**: find related Sysmon events (process, network, file, registry) around the same time and PID
4. **Timeline**: order the events into a narrative
5. **Assess**: decide whether it is a true positive, a benign true positive or a false positive
6. **Respond**: recommend containment and remediation
7. **Improve**: feed the findings back into detection tuning
8. **Report**: write it up in `investigations/INC-XXX/README.md` ([template](investigations/_TEMPLATE/README.md))

---

## Current Project Status

| Item | Status |
|---|---|
| Windows 11 + WSL2 + Ubuntu | Completed |
| Docker Desktop with WSL integration | Completed |
| Git repository and documentation scaffold | Completed |
| Wazuh stack (single-node, Docker) | Completed |
| Windows 11 lab VM with snapshots | Completed |
| Sysmon on the Windows endpoint | Completed |
| Wazuh agent and log ingestion | Completed |
| Full event archive and first end-to-end event trace | Completed |
| Windows audit policy and PowerShell script block logging | Completed |
| Atomic Red Team simulations | Planned |
| Custom detections | In Progress (1 / 5) |
| Investigations and incident reports | Planned (0 / 3) |
| Python automation | Planned |

---

## Disclaimer

All attack simulations in this project run **only in a controlled, isolated lab environment that I own**. They use established, publicly available testing frameworks such as Atomic Red Team. This repository contains **no malware, no exploit code and no offensive tooling** beyond what is needed to generate test telemetry. Do not run anything here against systems you do not own or are not explicitly authorized to test.

---

## Future Development Roadmap

- Stand up Wazuh in Docker and enroll a Windows endpoint running Sysmon
- Produce the first end-to-end alert from a controlled PowerShell test
- Build 5–10 ATT&CK-mapped detections with Sigma equivalents
- Write analyst-style investigations and incident reports
- Tune detections against realistic benign activity
- Automate alert parsing, IOC extraction, enrichment and coverage reporting in Python
- Add architecture diagrams, an ATT&CK coverage map and reproducible setup docs

See [ROADMAP.md](ROADMAP.md).
