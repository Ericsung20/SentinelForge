# SentinelForge: Roadmap

Status legend: **Completed** · **In Progress** · **Planned**

---

## Phase 0: Development Environment · **Completed**

- [x] Windows 11
- [x] WSL2 + Ubuntu
- [x] Docker Desktop with WSL integration
- [x] Git installed
- [x] Repository scaffold and documentation

---

## Phase 1: Infrastructure · **In Progress**

```
Windows → Sysmon → Wazuh Agent → Wazuh
```

- [x] Deploy single-node Wazuh (Manager, Indexer, Dashboard) with Docker → `infrastructure/`
- [ ] Prepare the Windows lab endpoint (a VM with snapshots is preferred)
- [ ] Install Sysmon with a documented baseline config → `telemetry/sysmon/`
- [ ] Enable the relevant Windows audit policies → `telemetry/windows-events/`
- [ ] Install and enroll the Wazuh agent
- [ ] Document every step in `docs/setup.md`

**Exit criteria:** the agent shows as active in the Wazuh dashboard.

---

## Phase 2: First Observable Security Event · Planned

```
Generate Windows activity → verify Sysmon event → verify ingestion into Wazuh
```

- [ ] Run a benign action (for example, launch `notepad.exe`)
- [ ] Confirm Sysmon Event ID 1 locally in Event Viewer
- [ ] Configure the agent to collect `Microsoft-Windows-Sysmon/Operational`
- [ ] Find the same event in the Wazuh dashboard
- [ ] Record the full field mapping (Sysmon field → Wazuh field)

**Exit criteria:** one event is traced from the endpoint to the dashboard, with screenshots.

---

## Phase 3: First Detection · Planned

```
Attack → Sysmon Event → Wazuh → Detection → Alert
```

- [ ] Choose a safe, controlled behavior (for example, an Atomic Red Team PowerShell test for T1059.001)
- [ ] Run it in the lab and inspect the raw telemetry
- [ ] Write a Wazuh custom rule → `detections/wazuh/`
- [ ] Confirm the alert fires
- [ ] Document the rule using `detections/TEMPLATE.md`

**Exit criteria:** one custom rule fires on a documented simulation.

---

## Phase 4: Detection Engineering · Planned

- [ ] Select 5–10 ATT&CK techniques
- [ ] For each: simulate → inspect telemetry → write the Wazuh rule → write the Sigma equivalent → validate
- [ ] Maintain a coverage table (technique → rule → status)

**Exit criteria:** at least 5 documented detections with successful alerts (MVP).

---

## Phase 5: Investigation · Planned

- [ ] Treat alerts as real incidents
- [ ] Build timelines from related Sysmon events (process tree, network, file, registry)
- [ ] Write incident reports using `investigations/_TEMPLATE/`

**Exit criteria:** 3 investigations and 3 incident reports (MVP).

---

## Phase 6: Detection Tuning · Planned

```
Initial Rule → False Positives → Tuning → Improved Detection
```

- [ ] Generate normal, benign activity against each rule
- [ ] Record the false positives
- [ ] Tune each rule (exclusions, tighter conditions, correlation)
- [ ] Document the before and after in each detection's Tuning Notes

---

## Phase 7: Automation · Planned

Python tooling in `automation/` for:

- [ ] Alert parsing (Wazuh alert JSON)
- [ ] IOC extraction
- [ ] Enrichment
- [ ] Detection coverage analysis (ATT&CK mapping)
- [ ] Incident report generation

---

## Phase 8: Portfolio Polish · Planned

- [ ] Architecture diagrams
- [ ] ATT&CK detection coverage map
- [ ] Curated incident reports
- [ ] Screenshots
- [ ] Reproducible setup documentation

---

## Later (post-v1 ideas, not committed)

- Linux endpoint with auditd
- More log sources (DNS, firewall)
- Threat hunting notebooks
