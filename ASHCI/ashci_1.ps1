<#
.SYNOPSIS
	Azure Stack HCI Deployment
 Forked from  https://github.com/microsoft/

.DESCRIPTION
	Azure Stack HCI Deployment

.INPUTS
	---

.OUTPUTS Log File
	ashci.log which is written in the PSSCRIPTROOT

.NOTES
  Version:        1.0
  Author:         Marco Mannoni
  Creation Date:  15.05.2019
  Purpose/Change: Initial script development

.CHANGES

#>

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

#Verify as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
	exit
}

#region variables

#ASHCI servers
#Servernamen
$Servers = "server01", "server02", "server03"

#features to be installed
#Features die installiert werden sollen
$FeatureList = "Hyper-V", "Failover-Clustering", "RSAT-Clustering", "RSAT-Clustering-Mgmt", "RSAT-Clustering-PowerShell", "Hyper-V-PowerShell", "FS-FileServer"

#cluster and CAU name
#Clustername
$ClusterName="clustername"

## Networking ##
#Netwerk Konfiguration

#If blank (you can write just $ClusterIP="", DHCP will be used)
#Wenn keine IP angegeben, wird DHCP gemacht
$ClusterIP=""

#IP Ranges
#IP Ranges der SMB Adapter
$Var_IP_lo10 = 10
$Var_IP_lo11 = 11
$Var_IP_lo12 = 12

#VLAN
#VLAN Management Adapter
$HCSVLAN = 600

#VLAN SMB Adapter
$StorVLAN1=1711
$StorVLAN2=1712
$StorVLAN3=1713
$StorVLAN4=1714

#SRIOV
#$false = kein SRVIOV, $true = SRIOV
$SRIOV=$false 

#PFC?
#$true for ROCE, $false for iWARP
#$true für RoCE (Mellanox), $false für iWARP (Chelsio)
$DCB=$False 

#iWARP?
$iWARP=$true

#DisableNetBIOS on all vNICs?
#Netbios dekativieren. $true = deaktivieren, $false = nicht deaktivieren
$DisableNetBIOS=$true

#Memory dump type (Active or Kernel) https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/varieties-of-kernel-mode-dump-files
#Memory Dump Typ einstellen
$MemoryDump="Kernel"

#Additional Features
#Zusätzliche Features installieren
$SystemInsights=$true #install "System-Insights" on nodes?

#endregion

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#grab Time and start Transcript
#Zeit abfragen und Log File starten
Start-Transcript -Path "$psscriptroot\ashci.log"
$StartDateTime = get-date

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#region configure basic settings on servers

#configure memory dump
if ($MemoryDump -eq "Kernel"){
	Invoke-Command -ComputerName $servers -ScriptBlock {
	Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -value 2
	}
}
if ($MemoryDump -eq "Active"){
	Invoke-Command -ComputerName $servers -ScriptBlock {
		Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -value 1
		Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\CrashControl -Name FilterPages -value 1
	}
}

#set high performance power plan
Invoke-Command -ComputerName $servers -ScriptBlock {powercfg /SetActive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}

#install roles and features
Invoke-Command -ComputerName $servers -ScriptBlock {
	$Result=Install-WindowsFeature -Name "Hyper-V" -ErrorAction SilentlyContinue
	if ($result.ExitCode -eq "failed"){
		Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -NoRestart
	}
}

#define features
$features="Failover-Clustering","Hyper-V-PowerShell","RSAT-Clustering-PowerShell"
if ($SystemInsights){$features+="System-Insights","RSAT-System-Insights"}

#install features
Invoke-Command -ComputerName $servers -ScriptBlock {Install-WindowsFeature -Name $using:features}

#restart and wait for computers
Restart-Computer $servers -Force -Protocol WSMan -Wait -For PowerShell
Start-Sleep 20 #Failsafe as Hyper-V needs 2 reboots and sometimes it happens, that during the first reboot the restart-computer evaluates the machine is up

#endregion

#region configure Networking

#rename physical adapater
Rename-NetAdapter -Name "Embedded LOM 1 Port 1" -NewName "LOM_1.1" -CimSession $servers
Rename-NetAdapter -Name "Embedded LOM 1 Port 2" -NewName "LOM_1.2" -CimSession $servers
Rename-NetAdapter -Name "Embedded LOM 1 Port 3" -NewName "LOM_1.3" -CimSession $servers
Rename-NetAdapter -Name "Embedded LOM 1 Port 4" -NewName "LOM_1.4" -CimSession $servers
Rename-NetAdapter -Name "PCIe Slot 2" -NewName "PCIe_Slot_1.1" -CimSession $servers
Rename-NetAdapter -Name "PCIe Slot 2 2" -NewName "PCIe_Slot_1.2" -CimSession $servers
Rename-NetAdapter -Name "PCIe Slot 5" -NewName "PCIe_Slot_2.1" -CimSession $servers
Rename-NetAdapter -Name "PCIe Slot 5 2" -NewName "PCIe_Slot_2.2" -CimSession $servers


#disable unused onboard nics
Disable-NetAdapter -Name "LOM_1.2" -Confirm:$false -CimSession $servers
Disable-NetAdapter -Name "LOM_1.3" -Confirm:$false -CimSession $servers
Disable-NetAdapter -Name "LOM_1.4" -Confirm:$false -CimSession $servers


#Create Virtual Switches and Virtual Adapters
if ($SRIOV){
	Invoke-Command -ComputerName $servers -ScriptBlock {New-VMSwitch -Name SETSwitch -EnableEmbeddedTeaming $TRUE -EnableIov $true -MinimumBandwidthMode Weight -NetAdapterName (Get-NetIPAddress -IPAddress PCIe* ).InterfaceAlias}
    Invoke-Command -ComputerName $Servers -ScriptBlock {Set-VMSwitchTeam -Name "SETSwitch" -LoadBalancingAlgorithm Dynamic}
}else{
	Invoke-Command -ComputerName $servers -ScriptBlock {New-VMSwitch -Name SETSwitch -EnableEmbeddedTeaming $TRUE -MinimumBandwidthMode Weight -NetAdapterName (Get-NetAdapter -Name PCIe*).InterfaceAlias}
    Invoke-Command -ComputerName $Servers -ScriptBlock {Set-VMSwitchTeam -Name "SETSwitch" -LoadBalancingAlgorithm Dynamic}
}

#Configure vNICs
$Servers | ForEach-Object {
Rename-VMNetworkAdapter -ManagementOS -Name SETSwitch -NewName Management -ComputerName $_
Add-VMNetworkAdapter -ManagementOS -Name SMB1 -SwitchName SETSwitch -CimSession $_
Add-VMNetworkAdapter -ManagementOS -Name SMB2 -SwitchName SETSwitch -Cimsession $_
Add-VMNetworkAdapter -ManagementOS -Name SMB3 -SwitchName SETSwitch -CimSession $_
Add-VMNetworkAdapter -ManagementOS -Name SMB4 -SwitchName SETSwitch -Cimsession $_
}

#configure IP Addresses
#10
New-NetIPAddress -IPAddress 192.168.1.$Var_IP_lo10 -InterfaceAlias "vEthernet (vSMB1)" -CimSession R3018HCS010 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.2.$Var_IP_lo10 -InterfaceAlias "vEthernet (vSMB2)" -CimSession R3018HCS010 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.3.$Var_IP_lo10 -InterfaceAlias "vEthernet (vSMB3)" -CimSession R3018HCS010 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.4.$Var_IP_lo10 -InterfaceAlias "vEthernet (vSMB4)" -CimSession R3018HCS010 -PrefixLength 24
#11
New-NetIPAddress -IPAddress 192.168.1.$Var_IP_lo11 -InterfaceAlias "vEthernet (vSMB1)" -CimSession R3018HCS011 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.2.$Var_IP_lo11 -InterfaceAlias "vEthernet (vSMB2)" -CimSession R3018HCS011 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.3.$Var_IP_lo11 -InterfaceAlias "vEthernet (vSMB3)" -CimSession R3018HCS011 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.4.$Var_IP_lo11 -InterfaceAlias "vEthernet (vSMB4)" -CimSession R3018HCS011 -PrefixLength 24
#12
New-NetIPAddress -IPAddress 192.168.1.$Var_IP_lo12 -InterfaceAlias "vEthernet (vSMB1)" -CimSession R3018HCS012 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.2.$Var_IP_lo12 -InterfaceAlias "vEthernet (vSMB2)" -CimSession R3018HCS012 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.3.$Var_IP_lo12 -InterfaceAlias "vEthernet (vSMB3)" -CimSession R3018HCS012 -PrefixLength 24
New-NetIPAddress -IPAddress 192.168.4.$Var_IP_lo12 -InterfaceAlias "vEthernet (vSMB4)" -CimSession R3018HCS012 -PrefixLength 24


Start-Sleep 5
Clear-DnsClientCache

#Configure the host vNIC to use a Vlans
Set-VMNetworkAdapterVlan -VMNetworkAdapterName vHCS -VlanId $HCSVLAN -Access -ManagementOS -CimSession $Servers
Set-VMNetworkAdapterVlan -VMNetworkAdapterName vSMB1 -VlanId $StorVLAN1 -Access -ManagementOS -CimSession $Servers
Set-VMNetworkAdapterVlan -VMNetworkAdapterName vSMB2 -VlanId $StorVLAN2 -Access -ManagementOS -CimSession $Servers
Set-VMNetworkAdapterVlan -VMNetworkAdapterName vSMB3 -VlanId $StorVLAN3 -Access -ManagementOS -CimSession $Servers
Set-VMNetworkAdapterVlan -VMNetworkAdapterName vSMB4 -VlanId $StorVLAN4 -Access -ManagementOS -CimSession $Servers

#remove dns registration of SMB adapaters
Set-DNSClient �RegisterThisConnectionsAddress $False -InterfaceAlias "vEthernet (vSMB1)" -CimSession $Servers
Set-DNSClient �RegisterThisConnectionsAddress $False -InterfaceAlias "vEthernet (vSMB2)" -CimSession $Servers
Set-DNSClient �RegisterThisConnectionsAddress $False -InterfaceAlias "vEthernet (vSMB3)" -CimSession $Servers
Set-DNSClient �RegisterThisConnectionsAddress $False -InterfaceAlias "vEthernet (vSMB4)" -CimSession $Servers

#Restart each host vNIC adapter so that the Vlan is active.
Restart-NetAdapter "vEthernet (vSMB1)" -CimSession $Servers
Restart-NetAdapter "vEthernet (vSMB2)" -CimSession $Servers
Restart-NetAdapter "vEthernet (vSMB3)" -CimSession $Servers
Restart-NetAdapter "vEthernet (vSMB4)" -CimSession $Servers

#Enable RDMA on the host vNIC adapters
Enable-NetAdapterRDMA "vEthernet (vSMB1)","vEthernet (vSMB2)","vEthernet (vSMB3)","vEthernet (vSMB4)" -CimSession $Servers

#Associate each of the vNICs configured for RDMA to a physical adapter that is up and is not virtual (to be sure that each RDMA enabled ManagementOS vNIC is mapped to separate RDMA pNIC)
Invoke-Command -ComputerName $servers -ScriptBlock {
	$physicaladapters=(get-vmswitch SETSwitch).NetAdapterInterfaceDescriptions | Sort-Object
	Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName "vSMB1" -ManagementOS -PhysicalNetAdapterName (get-netadapter -InterfaceDescription $physicaladapters[0]).name
	Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName "vSMB2" -ManagementOS -PhysicalNetAdapterName (get-netadapter -InterfaceDescription $physicaladapters[1]).name
	Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName "vSMB3" -ManagementOS -PhysicalNetAdapterName (get-netadapter -InterfaceDescription $physicaladapters[0]).name
	Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName "vSMB4" -ManagementOS -PhysicalNetAdapterName (get-netadapter -InterfaceDescription $physicaladapters[1]).name
}

#Disable NetBIOS on all vNICs
if ($DisableNetBIOS){
	$vNICs = Get-NetAdapter -CimSession $Servers | Where-Object Name -like vEthernet*
	foreach ($vNIC in $vNICs){
		Write-Host "Disabling NetBIOS on $($vNIC.Name) on computer $($vNIC.PSComputerName)"
		$output=Get-WmiObject -class win32_networkadapterconfiguration -ComputerName $vNIC.PSComputerName | Where-Object Description -eq $vNIC.InterfaceDescription | Invoke-WmiMethod -Name settcpipNetBIOS -ArgumentList 2
		if ($output.Returnvalue -eq 0){
			Write-Host "`t Success" -ForegroundColor Green
		}else{
			Write-Host "`t Failure"
		}
	}
}

#Verify Networking
#verify mapping
Get-VMNetworkAdapterTeamMapping -CimSession $servers -ManagementOS | ft ComputerName,NetAdapterName,ParentAdapter

#Verify that the VlanID is set
Get-VMNetworkAdapterVlan -ManagementOS -CimSession $servers |Sort-Object -Property Computername | ft ComputerName,AccessVlanID,ParentAdapter -AutoSize -GroupBy ComputerName

#verify RDMA
Get-NetAdapterRdma -CimSession $servers | Sort-Object -Property Systemname | ft systemname,interfacedescription,name,enabled -AutoSize -GroupBy Systemname

#verify ip config 
Get-NetIPAddress -CimSession $servers -InterfaceAlias vEthernet* -AddressFamily IPv4 | Sort-Object -Property PSComputername | ft pscomputername,interfacealias,ipaddress -AutoSize -GroupBy pscomputername

#enable iWARP firewall rule if requested
if ($iWARP -eq $True){
	Enable-NetFirewallRule -Name "FPSSMBD-iWARP-In-TCP" -CimSession $servers
}

#endregion


#region hci cluster and configure basic settings
Test-Cluster -Node $servers -Include "Storage Spaces Direct","Inventory","Network","System Configuration","Hyper-V Configuration"
if ($ClusterIP){
	New-Cluster -Name $ClusterName -Node $servers -StaticAddress $ClusterIP -NoStorage
}else{
	New-Cluster -Name $ClusterName -Node $servers -NoStorage
}
Start-Sleep 5
Clear-DnsClientCache

#Configure CSV Cache 16GB
(Get-Cluster $ClusterName).BlockCacheSize = 16384

#endregion

#region Configure Cluster Networks

#rename networks
(Get-ClusterNetwork -Cluster $clustername | Where-Object Address -eq $StorNet"0").Name="SMB"
(Get-ClusterNetwork -Cluster $clustername | Where-Object Address -eq "172.16.50.0").Name="Management"

#configure Live Migration 
Get-ClusterResourceType -Cluster $clustername -Name "Virtual Machine" | Set-ClusterParameter -Name MigrationExcludeNetworks -Value ([String]::Join(";",(Get-ClusterNetwork -Cluster $clustername | Where-Object {$_.Name -ne "SMB"}).ID))
Set-VMHost -VirtualMachineMigrationPerformanceOption SMB -cimsession $servers
#endregion

#region configure Cluster-Aware-Updating
Add-CauClusterRole -ClusterName $ClusterName -MaxFailedNodes 0 -RequireAllNodesOnline -EnableFirewallRules -VirtualComputerObjectName $CAURoleName -Force -CauPluginName Microsoft.WindowsUpdatePlugin -MaxRetriesPerNode 3 -CauPluginArguments @{ 'IncludeRecommendedUpdates' = 'true' } -StartDate "1/1/2030 3:00:00 AM" -DaysOfWeek 4 -WeeksOfMonth @(3) -verbose
#endregion


#region Enable Cluster S2D and check Pool and Tiers

#Enable-ClusterS2D
Enable-clusterstoragespacesdirect -CimSession $ClusterName -confirm:0 -Verbose

#display pool
Get-StoragePool "S2D on $ClusterName" -CimSession $ClusterName

#Display disks
Get-StoragePool "S2D on $ClusterName" -CimSession $ClusterName | Get-PhysicalDisk -CimSession $ClusterName

#Get Storage Tiers
Get-StorageTier -CimSession $ClusterName