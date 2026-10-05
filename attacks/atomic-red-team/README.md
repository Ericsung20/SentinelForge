# Atomic Red Team

[Atomic Red Team](https://github.com/redcanaryco/atomic-red-team) (Red Canary) is a library of small, documented tests mapped to MITRE ATT&CK. The lab uses it to reproduce a technique on the Windows VM, then checks what the telemetry and the detections caught.

Run tests **only on the lab VM**, from a known snapshot, and run each test's cleanup afterwards.

## Install on the lab VM

1. **Defender exclusion for `C:\AtomicRedTeam`.** Many atomics are flagged as malicious and quarantined otherwise. Add it by hand: **Windows Security → Virus & threat protection → Manage settings → Exclusions → Add an exclusion → Folder**. Adding it fires [rule 100100](../../detections/defender-exclusion-added.md), which is expected.
2. **Elevated PowerShell** (Win+R → `powershell` → Ctrl+Shift+Enter). Make sure the prompt is `PS C:\...>`. If the window says *Command Prompt*, type `powershell` first.
3. Allow script modules for this window only (the default *Restricted* policy blocks the `powershell-yaml` dependency). This doesn't change the machine's policy:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```
4. Install the framework and the atomics:
   ```powershell
   IEX (IWR https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1 -UseBasicParsing); Install-AtomicRedTeam -getAtomics
   ```
   If a first attempt failed partway, the retry reports *"already exists ... No changes were made"*. Rerun with `-Force` to reinstall cleanly.

Expected: `Installation of Invoke-AtomicRedTeam is complete.` Atomics land in `C:\AtomicRedTeam\atomics`. VM snapshot after install: `07-atomic-red-team`.

## Running a test

Every new PowerShell window needs step 3 again. Read the test before running it:

```powershell
Invoke-AtomicTest T1059.001 -ShowDetailsBrief             # list tests for a technique
Invoke-AtomicTest T1059.001 -TestNumbers 10 -ShowDetails  # what one test runs, and its cleanup
Invoke-AtomicTest T1059.001 -TestNumbers 10 -CheckPrereqs
Invoke-AtomicTest T1059.001 -TestNumbers 10
Invoke-AtomicTest T1059.001 -TestNumbers 10 -Cleanup
```

## Tests used

| Technique | Test | Why chosen | Detection |
|---|---|---|---|
| T1059.001 | 10: PowerShell Fileless Script Execution | Harmless payload (writes a marker file) hidden as Base64 in the registry and run from memory | [Rule 100110](../../detections/powershell-base64-iex.md). Defender blocks the payload (`Trojan:Win32/Powessere.K`); the rule fires on the command line anyway |

Tests skipped on purpose: T1059.001-1 to 4 (Mimikatz, BloodHound) pull in real credential-theft and Active Directory tooling that this single-host lab doesn't need.
