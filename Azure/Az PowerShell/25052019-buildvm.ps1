<#
.SYNOPSIS
  VM Deployment Beispiel

.DESCRIPTION
  VM Deployment Beispiel

.INPUTS
	-

.OUTPUTS Log File
	-

.NOTES
  Version:        1.0
  Author:         Marco Mannoni
  Creation Date:  25.05.2019
  Purpose/Change: Initial script development

.CHANGES

#>

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Lokaler Admin definieren und Passwort abfragen
$credential = Get-Credential -UserName $locadminusername -Message "Bitte Passwort eingeben für $locadminusername"

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#regiondeployment

# Erstellen der Ressourcegruppe
New-AzResourceGroup -Name $paramvm.resourcegroup -Location $paramvm.location


# Netz und das Subnet auslesen
$vnet = Get-AzVirtualNetwork -Name $paramvnet.netname -ResourceGroupName $paramvnet.resourcegroupname
$subnetconfig = Get-AzVirtualNetworkSubnetConfig -Name $paramvnet.privsubnetname -VirtualNetwork $vnet


# Erstellen der Network Security Group mit Default Einstellungen
$nsg = New-AzNetworkSecurityGroup -Name $paramvm.nsgname -ResourceGroupName $paramvm.resourcegroup  -Location  $paramvm.location


# Erstellen der IP Konfiguration und des Netzwerkadapters
# Binden des Adapters an das Subnet das definiert ist. Einbinden der NSG
$ipconfig = New-AzNetworkInterfaceIpConfig -Name "IPConfigPrivate" -PrivateIpAddressversion IPv4 -PrivateIpAddress $paramvm.nicip -Subnetid $subnetconfig.Id
$nic = New-AzNetworkInterface -Name $paramvm.nicname -ResourceGroupName $paramvm.resourcegroup -Location $paramvm.location `
-NetworkSecurityGroupId $nsg.Id -IpConfiguration $ipconfig


# VM Konfiguration zusammenbauen
$vmconfig = New-AzVMConfig -VMName $paramvm.name -VMSize paramvm.size
$vmconfig = Set-AzVMOSDisk -VM $vmconfig -Name $paramvm.osdisk -StorageAccountType $paramvm.storageaccounttype -Caching ReadWrite -CreateOption fromImage
$vmconfig = Set-AzVMOperatingSystem -VM $vmconfig -Windows -ComputerName $paramvm.name -Credential $credential -ProvisionVMAgent
$vmconfig = Set-AzVMSourceImage -VM $vmconfig -PublisherName $paramvm.publishername -Offer $paramvm.offer -Skus $paramvm.sku -Version latest
$vmconfig = Add-AzVMNetworkInterface -VM $vmconfig -Id $nic.Id


# VM erstellen
New-AzVM -ResourceGroupName $vmconfig.resourcegroup -Location $vmconfig.location -VM $vmconfig -Verbose

#endregion
