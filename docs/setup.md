# Setup

Reproducible setup instructions, filled in as each phase is completed. Only verified steps go here.

## Phase 0: Development Environment · Completed

| Requirement | Notes |
|---|---|
| Windows 11 | Host OS |
| WSL2 + Ubuntu | The repository lives in the Ubuntu filesystem |
| Docker Desktop | WSL integration enabled for Ubuntu |
| Git | Used from WSL |
| RAM | 32 GB (a single-node Wazuh deployment needs roughly 8 GB or more) |

Verify:

```bash
wsl --status            # from Windows
docker version          # from WSL
docker compose version  # from WSL
git --version
```

Clone:

```bash
git clone https://github.com/Ericsung20/SentinelForge.git
cd SentinelForge
```

## Phase 1: Infrastructure · Completed

### 1.1 Wazuh single-node (Docker) · Completed

Uses the official [wazuh-docker](https://github.com/wazuh/wazuh-docker) single-node deployment, pinned to **v4.14.8**. The clone lives at `infrastructure/wazuh-docker/` and is git-ignored.

Prerequisite: Docker Desktop must be **running** on Windows. If WSL prints `The command 'docker' could not be found`, start Docker Desktop first (enable *Start Docker Desktop when you sign in* to avoid this).

```bash
# Wazuh indexer (OpenSearch) needs a higher mmap limit; persist it across WSL restarts
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-wazuh.conf
sudo sysctl --system > /dev/null

cd infrastructure
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.8
cd wazuh-docker/single-node
docker compose -f generate-indexer-certs.yml run --rm generator   # one-time: TLS certs
docker compose up -d
docker compose ps
```

Expected: three containers `Up`: `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard`.

| Port | Service |
|---|---|
| 443 | Dashboard → https://localhost (self-signed cert warning is expected) |
| 1514 / 1515 | Agent events / agent enrollment |
| 9200 | Indexer API |
| 55000 | Wazuh server API |

Login uses the upstream default credentials defined in `single-node/docker-compose.yml`. These are public defaults: change them before exposing the lab to any network.

Stop / start:

```bash
docker compose stop     # keeps data
docker compose start
```

### 1.2 Windows lab endpoint (VirtualBox VM) · Completed

| | |
|---|---|
| Hypervisor | VirtualBox 7.2.20 |
| Guest | Windows 11 Enterprise Evaluation 25H2 ([90-day ISO](https://www.microsoft.com/evalcenter/download-windows-11-enterprise)) |
| VM | 4 vCPU, 8 GB RAM, 80 GB dynamic disk, EFI + TPM 2.0 + Secure Boot |
| Network | NAT. The VM reaches the host (and Wazuh) at `10.0.2.2` |
| Isolation | Shared clipboard and drag-and-drop disabled |
| Account | Local account `labuser` (no Microsoft account) |

**Hyper-V note.** WSL2 and Docker Desktop keep the Windows hypervisor running, so VirtualBox cannot use VT-x directly and falls back to NEM (Windows Hypervisor Platform). The log shows `HM: HMR3Init: Attempting fall back to NEM: VT-x is not available`. NEM works but is slow, and two settings matter:

- **Keep 4 vCPUs.** With 2 vCPUs the VM hung in EFI firmware (`EFI: debug point DXE_AP`) before reaching the installer.
- **Graphics controller depends on the install stage.** Before Guest Additions, use **VMSVGA**; VBoxSVGA gives a black screen. After Guest Additions, switch to **VBoxSVGA**; VMSVGA gives a black screen.

Create the VM (Windows PowerShell on the host):

```powershell
.\infrastructure\virtualbox\New-LabVM.ps1 -IsoPath "$env:USERPROFILE\Downloads\<Win11 eval ISO>.iso"
```

The script starts the VM with VMSVGA graphics, ready for installation.

Install Windows:

1. Start the VM and press a key at `Press any key to boot from CD or DVD`. If the prompt is missed, reset the VM and try again, or send the key from the host: `VBoxManage controlvm SentinelForge-Win11 keyboardputscancode 39 b9`.
2. At the account screen choose **Sign-in options → Domain join instead** to create a local account.
3. If setup shows `Something went wrong: OOBESETTINGS`, choose **Skip**.
4. Choose **Update later** at the update screen. Update after the first snapshot so a bad update can be rolled back.

Install Guest Additions, then switch graphics:

```powershell
VBoxManage storageattach SentinelForge-Win11 --storagectl SATA --port 1 --device 0 --type dvddrive --medium additions
# In the VM: run D:\VBoxWindowsAdditions.exe, reboot. Then power off the VM and:
VBoxManage modifyvm SentinelForge-Win11 --graphicscontroller vboxsvga
VBoxManage storageattach SentinelForge-Win11 --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
```

Troubleshooting under NEM:

| Symptom | Cause / fix |
|---|---|
| Screen frozen, VM log fills with `VERR_PDM_NO_QUEUE_ITEMS` | The guest is too busy to take input (first-login background work). Wait, or power off and boot again. |
| Screen stuck but CPU busy | The display only redraws on input before Guest Additions. Send a key or move the mouse. |
| Next start shows the same hung screen | The window was closed with **Save the machine state**. Use **Power off** and `VBoxManage discardstate`. |
| Laptop has no Right Ctrl (default host key) | `VBoxManage setextradata global GUI/Input/HostKeyCombination "162,164"` sets Left Ctrl + Left Alt. |

To tell "slow" from "hung", watch the VM process: CPU time and disk (`.vdi`) growth mean the guest is still working.

### 1.3 Sysmon · Completed

In an elevated PowerShell on the VM (the shared clipboard is off, so type it or send it with `VBoxManage controlvm SentinelForge-Win11 keyboardputstring`):

```powershell
irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/telemetry/sysmon/Install-Sysmon.ps1 -OutFile $env:TEMP\Install-Sysmon.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\Install-Sysmon.ps1
```

Expected: `Configuration file validated`, service `Sysmon64` Running, and recent events listed. Verified with Sysmon 15.22. Details: [telemetry/sysmon/README.md](../telemetry/sysmon/README.md).

### 1.4 Wazuh agent · Completed

The manager must already have [`shared/default/agent.conf`](../infrastructure/wazuh/shared/default/agent.conf) deployed (see [infrastructure/wazuh/README.md](../infrastructure/wazuh/README.md)) so the agent collects Sysmon. With the Wazuh stack running, in an elevated PowerShell on the VM:

```powershell
irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/infrastructure/wazuh/Install-WazuhAgent.ps1 -OutFile $env:TEMP\Install-WazuhAgent.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\Install-WazuhAgent.ps1
```

Expected: `Wazuh agent '<hostname>' is connected to 10.0.2.2.`

Verify from WSL, in `infrastructure/wazuh-docker/single-node`:

```bash
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l   # agent listed as Active
docker compose exec wazuh.manager sh -c "grep -c Microsoft-Windows-Sysmon /var/ossec/logs/alerts/alerts.json"
```

The first Sysmon alerts came from the install scripts themselves, for example rule 92205 (PowerShell created an executable file in the Windows root folder).

### VM snapshots

| Snapshot | State |
|---|---|
| `01-clean-install` | Fresh Windows, local user, no updates |
| `02-guest-additions` | Guest Additions installed, VBoxSVGA |
| `03-sysmon` | Sysmon installed |
| `04-wazuh-agent` | Agent enrolled and Active. End of Phase 1 |
| `05-audit-policy` | Audit policy and PowerShell script block logging ([telemetry/windows-events](../telemetry/windows-events/README.md)). End of Phase 2 |
| `06-defender-exclusion` | Defender exclusion `C:\AtomicRedTeam` added for Atomic Red Team; the change fires [rule 100100](../detections/defender-exclusion-added.md). End of Phase 3 |

Restore one with `VBoxManage snapshot SentinelForge-Win11 restore <name>` while the VM is powered off.

## Secrets Handling

- Never commit passwords, API keys, tokens, certificates or agent keys.
- Put local values in `.env` (git-ignored). If a template is needed, commit `.env.example` with placeholder values only.
- Keep Wazuh-generated certificates out of Git (see `.gitignore`).
