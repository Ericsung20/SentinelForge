# Sysmon Baseline Config

`sysmonconfig.xml` is the default build of [sysmon-modular](https://github.com/olafhartong/sysmon-modular) by Olaf Hartong, used unmodified as the lab's starting point.

| | |
|---|---|
| Upstream release | [`configs-082cba578667`](https://github.com/olafhartong/sysmon-modular/releases/tag/configs-082cba578667) (2026-09-18) |
| Target Sysmon version | 15.21 (schema 4.91) |
| SHA256 | `f115aac5770dae468e5cfb48c58a8b6e37588208a31f1b746812c534577a244b` |
| License | MIT, see [`LICENSE-sysmon-modular`](LICENSE-sysmon-modular) |

Why this config: rules are grouped and tagged by MITRE ATT&CK technique (`technique_id=...` in each rule name), which makes it easy to trace a Sysmon event back to the behavior it was written to catch. It is actively maintained and ships checksums with each release.

## Install on the lab endpoint

Run in an elevated PowerShell on the Windows VM:

```powershell
irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/telemetry/sysmon/Install-Sysmon.ps1 -OutFile $env:TEMP\Install-Sysmon.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\Install-Sysmon.ps1
```

[`Install-Sysmon.ps1`](Install-Sysmon.ps1) downloads this config and Sysmon from [Sysinternals](https://learn.microsoft.com/sysinternals/downloads/sysmon), checks the config's SHA256 and Sysmon64.exe's Microsoft signature, then installs Sysmon. If Sysmon is already installed, it only updates the config.

Manual equivalent, from a folder containing `Sysmon64.exe` and this config:

```powershell
.\Sysmon64.exe -accepteula -i sysmonconfig.xml   # install
.\Sysmon64.exe -c sysmonconfig.xml                # update config
```

Events are written to **Applications and Services Logs → Microsoft → Windows → Sysmon → Operational**.

## Updating from upstream

```bash
B=https://github.com/olafhartong/sysmon-modular/releases/download/<release-tag>
curl -fsSLO "$B/sysmonconfig.xml"
curl -fsSL "$B/SHA256SUMS" | grep ' sysmonconfig.xml$' | sha256sum -c -
```

Then update the table above. Lab-specific changes go in a separate commit so they stay distinguishable from upstream.
