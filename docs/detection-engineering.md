# Detection Engineering

How SentinelForge detections are built, documented and improved.

## Lifecycle

```
Select an ATT&CK technique
  → Simulate it (Atomic Red Team, in the lab only)
  → Inspect the raw telemetry (Sysmon / Event Logs)
  → Write the detection logic (Wazuh rule, then the Sigma equivalent)
  → Test: does it fire on the simulation?
  → Test: what benign activity also triggers it?
  → Tune
  → Document it and map it to ATT&CK
```

## Required Documentation per Detection

Every detection **must** have a documentation file based on [detections/TEMPLATE.md](../detections/TEMPLATE.md) that records:

| Field | Purpose |
|---|---|
| Rule Name | Short, descriptive and unique |
| Description | The behavior it detects and why that matters |
| MITRE ATT&CK Technique | Technique ID and name (for example T1059.001) |
| Data Source | Log channel and Event IDs (for example Sysmon EID 1) |
| Detection Logic | The fields and conditions it matches, in plain language, plus the rule itself |
| False Positives | Known or expected benign triggers |
| Testing Procedure | Exact, reproducible steps that trigger it (such as the Atomic test ID) |
| Expected Result | What should happen (rule ID, alert level, key fields) |
| Actual Result | What actually happened, with evidence (a screenshot or alert excerpt) |
| Tuning Notes | Changes made after testing, with before and after |

## File Layout

```
detections/
├── TEMPLATE.md
├── wazuh/
│   ├── <technique>-<short-name>.xml     # Wazuh rule
│   └── <technique>-<short-name>.md      # Documentation (from TEMPLATE.md)
└── sigma/
    └── <technique>-<short-name>.yml     # Sigma rule
```

Example name: `T1059.001-encoded-powershell`.

## Conventions

- **Custom Wazuh rule IDs:** use the 100000–120999 range reserved for local rules.
- **One behavior per rule:** prefer several precise rules over one broad rule.
- **Telemetry before logic:** paste a redacted sample event into the doc before writing the rule.
- **Status field:** mark each detection Planned, In Progress (written but not validated) or Completed (validated and documented).

## Coverage Tracking

| Technique | Name | Wazuh rule | Sigma rule | Status |
|---|---|---|---|---|
| _None yet_ | | | | |
