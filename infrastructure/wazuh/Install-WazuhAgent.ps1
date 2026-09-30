#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Wazuh agent on the lab endpoint and enrolls it with the lab manager.

.DESCRIPTION
    Checks the manager is reachable, downloads the agent MSI, verifies its Wazuh, Inc. Authenticode signature,
    installs it silently and waits until the agent reports "connected".
    The agent joins the "default" group, so it receives shared/default/agent.conf (Sysmon collection) automatically.

.EXAMPLE
    # On the lab endpoint, in an elevated PowerShell:
    irm https://raw.githubusercontent.com/Ericsung20/SentinelForge/main/infrastructure/wazuh/Install-WazuhAgent.ps1 -OutFile $env:TEMP\Install-WazuhAgent.ps1
    powershell -ExecutionPolicy Bypass -File $env:TEMP\Install-WazuhAgent.ps1
#>
param(
    [string] $Manager = '10.0.2.2',          # VirtualBox NAT gateway = the host running wazuh-docker
    [string] $AgentName = $env:COMPUTERNAME,
    [string] $Version = '4.14.8-1'           # keep in step with the manager version
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

foreach ($port in 1514, 1515) {
    if (-not (Test-NetConnection $Manager -Port $port -InformationLevel Quiet)) {
        throw "Cannot reach Wazuh manager at ${Manager}:$port. Is the wazuh-docker stack running?"
    }
}

$msi = Join-Path $env:TEMP "wazuh-agent-$Version.msi"
Invoke-WebRequest "https://packages.wazuh.com/4.x/windows/wazuh-agent-$Version.msi" -OutFile $msi -UseBasicParsing
$sig = Get-AuthenticodeSignature $msi
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O="Wazuh, Inc"') {
    throw "Agent MSI signature check failed: $($sig.Status) $($sig.SignerCertificate.Subject)"
}

$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$msi`" /q WAZUH_MANAGER=$Manager WAZUH_AGENT_NAME=$AgentName"
if ($p.ExitCode -ne 0) { throw "msiexec exited with code $($p.ExitCode)" }
Start-Service WazuhSvc

$state = "${env:ProgramFiles(x86)}\ossec-agent\wazuh-agent.state"
for ($i = 0; $i -lt 30; $i++) {
    if ((Test-Path $state) -and (Select-String $state -Pattern "status='connected'" -Quiet)) {
        Write-Host "Wazuh agent '$AgentName' is connected to $Manager."
        return
    }
    Start-Sleep 2
}
throw "Agent installed but not connected after 60s. Check ${env:ProgramFiles(x86)}\ossec-agent\ossec.log"
