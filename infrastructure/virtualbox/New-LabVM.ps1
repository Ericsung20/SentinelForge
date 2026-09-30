<#
.SYNOPSIS
    Creates the SentinelForge Windows 11 lab endpoint VM in VirtualBox.

.DESCRIPTION
    Windows 11 requirements: EFI, TPM 2.0, Secure Boot.
    Isolation: NAT networking (no inbound access), clipboard and drag-and-drop disabled.
    The VM reaches Wazuh on the host at 10.0.2.2 (VirtualBox NAT gateway).

    With WSL2/Docker running, VirtualBox runs in NEM mode (no direct VT-x). Under NEM:
    - keep 4 vCPUs; with 2 the VM hung in EFI before reaching the installer
    - graphics starts as VMSVGA (VBoxSVGA is black before Guest Additions);
      switch to VBoxSVGA after installing Guest Additions (VMSVGA is black after)

.EXAMPLE
    .\New-LabVM.ps1 -IsoPath "$env:USERPROFILE\Downloads\Win11_Enterprise_Eval.iso"
#>
param(
    [Parameter(Mandatory)] [string] $IsoPath,
    [string] $Name = 'SentinelForge-Win11',
    [int] $MemoryMB = 8192,
    [int] $Cpus = 4,
    [int] $DiskMB = 81920
)

$ErrorActionPreference = 'Stop'
$vbox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"

function Invoke-VBox {
    & $vbox @args
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args[0]) failed (exit $LASTEXITCODE)" }
}

if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }
if ((& $vbox list vms) -match "`"$Name`"") { throw "VM '$Name' already exists" }

Invoke-VBox createvm --name $Name --ostype Windows11_64 --register
$cfg = (& $vbox showvminfo $Name --machinereadable | Select-String '^CfgFile=').Line.Split('=', 2)[1].Trim('"')
$disk = Join-Path (Split-Path $cfg) "$Name.vdi"

Invoke-VBox modifyvm $Name --memory $MemoryMB --cpus $Cpus --vram 128 --graphicscontroller vmsvga `
    --firmware efi --tpm-type 2.0 --nic1 nat --clipboard-mode disabled --drag-and-drop disabled

# Secure Boot: initialize the UEFI variable store and enroll the default keys
Invoke-VBox modifynvram $Name inituefivarstore
Invoke-VBox modifynvram $Name enrollmssignatures
Invoke-VBox modifynvram $Name enrollorclpk

Invoke-VBox createmedium disk --filename $disk --size $DiskMB --format VDI
Invoke-VBox storagectl $Name --name SATA --add sata --controller IntelAhci
Invoke-VBox storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
Invoke-VBox storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $IsoPath

Write-Host "Created '$Name'. Start it and press a key at 'Press any key to boot from CD or DVD'."
Write-Host "After installing Guest Additions, power off and run: VBoxManage modifyvm $Name --graphicscontroller vboxsvga"
