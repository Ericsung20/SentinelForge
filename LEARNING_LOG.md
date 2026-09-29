# SentinelForge: Learning Log

A running journal of what I built, what broke and what I learned. Newest entries go at the top. Copy the template below for each session.

---

## Entry Template

```markdown
### YYYY-MM-DD: <Topic>

**Phase:** <0–8>

**What I worked on**
-

**What I learned**
-

**Problems encountered**
-

**How I solved them**
-

**Security concepts learned**
-

**Next step**
-
```

---

## Entries

### 2026-09-29: Sysmon config, agent config and the Windows lab VM

**Phase:** 1

**What I worked on**
- Added the sysmon-modular baseline config under `telemetry/sysmon/` and verified it against the upstream SHA256 checksum.
- Added a centralized Wazuh agent config (`infrastructure/wazuh/shared/default/agent.conf`) that collects `Microsoft-Windows-Sysmon/Operational`, validated it with `verify-agent-conf` and deployed it to the manager.
- Added `.gitattributes` so line endings stay consistent between Windows and WSL.
- Wrote `infrastructure/virtualbox/New-LabVM.ps1` and created the Windows 11 lab VM with it (EFI, TPM 2.0, Secure Boot, NAT, clipboard off).
- Started installing Windows 11 Enterprise Evaluation in the VM. Not finished yet.

**What I learned**
- Wazuh agents only collect Application, Security and System logs by default. Sysmon's channel has to be added explicitly. A group `agent.conf` on the manager is pushed to agents automatically, so the endpoint needs no manual config.
- Wazuh ships built-in decoders and rules for Sysmon, so events are analyzed as soon as they arrive.
- A vendored file must stay byte-identical to verify its published checksum. Git line-ending normalization would change it, so the file is marked `-text`.
- When Hyper-V is running (WSL2 and Docker need it), VirtualBox cannot use VT-x directly. It falls back to NEM mode through the Windows Hypervisor Platform, which is slower and less stable.
- A VM can look frozen while it is still working. Checking CPU time and disk growth of the VM process tells the difference between "slow" and "hung".
- GitHub's contribution graph is not real-time, and rewriting history resets counting for the rewritten commits.

**Problems encountered**
- The first install froze at 22%: no CPU use, no disk writes, and the log filled with mouse-queue errors.
- With 2 vCPUs, the VM hung in EFI firmware (`DXE_AP`) with a black screen before reaching the installer.
- Closing the VM window defaulted to "Save the machine state", so the next start restored the hung state instead of booting.
- My laptop has no right Ctrl key, which is VirtualBox's default host key for releasing the mouse.
- After the Windows files finished installing, the first boot showed a white screen and then a black one. Windows was active (CPU, disk, network link) but never drew the setup screen and ignored the ACPI shutdown signal.

**How I solved them**
- Read `VBox.log`, which showed `VT-x is not available` and the fallback to NEM.
- Recreated the disk and went back to 4 vCPUs, which got past the EFI hang. 2 vCPUs was worse under NEM on this hybrid-core Intel CPU.
- Used "Power off the machine" and `VBoxManage discardstate` instead of saving state.
- Changed the host key to Left Ctrl + Left Alt and turned off keyboard auto-capture.
- Sent the "press any key to boot from CD" keystroke with `VBoxManage controlvm keyboardputscancode`.
- Still open: the black screen in Windows setup. Next I will try the VMSVGA graphics controller, then running VirtualBox with the hypervisor disabled during installation.

**Security concepts learned**
- Verify third-party security content (checksum plus license) before trusting it.
- Keep the attack-simulation endpoint isolated: NAT only, no shared clipboard or drag-and-drop with the host.
- Central configuration management keeps endpoint telemetry settings consistent and auditable in Git.

**Next step**
- Get Windows setup to display, take a clean snapshot, then install Sysmon and enroll the Wazuh agent.

### 2026-09-28: Wazuh single-node deployment

**Phase:** 1

**What I worked on**
- Archived the early Python prototype under `automation/legacy/`.
- Deployed Wazuh v4.14.8 (manager, indexer, dashboard) with the official single-node Docker Compose setup and logged in to the dashboard.

**What I learned**
- Wazuh has three parts: the manager analyzes events, the indexer (OpenSearch) stores and searches them, and the dashboard is the web UI.
- The indexer needs `vm.max_map_count=262144`. `sysctl -w` resets when WSL restarts, so the value also goes in `/etc/sysctl.d/`.
- Docker Desktop provides the `docker` command inside WSL, so it only works while Docker Desktop is running on Windows.
- Cloning a third-party repo at a pinned release tag makes the setup reproducible. The clone stays git-ignored because it is not my code.

**Problems encountered**
- `git clone -b v4.X.Y` failed because I ran the placeholder tag literally.
- WSL reported `The command 'docker' could not be found`.

**How I solved them**
- Looked up the real latest tag with `git ls-remote --tags` and cloned `v4.14.8`.
- Docker Desktop was installed but not running. Starting it fixed the error.

**Security concepts learned**
- The indexer uses TLS certificates generated locally. Certificates and keys never go into Git.
- The deployment ships with public default credentials, which must be changed before the lab touches any real network.
- The Windows endpoint should be an isolated VM with snapshots, so attack simulations cannot harm the host.

**Next step**
- Build the Windows lab VM, then install Sysmon and the Wazuh agent.

### 2026-09-28: Repository setup

**Phase:** 0

**What I worked on**
- Initialized the SentinelForge repository, its structure and the planning docs (README, PRD, ROADMAP).

**What I learned**
-

**Problems encountered**
-

**How I solved them**
-

**Security concepts learned**
-

**Next step**
- Phase 1: deploy single-node Wazuh with Docker.
