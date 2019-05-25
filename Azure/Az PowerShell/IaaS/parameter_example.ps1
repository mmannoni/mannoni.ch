<#
.SYNOPSIS
  Parameter Beispiel

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


# Virtuelle Netzwerk Parameter

$paramvnet = @{}
$paramvnet.Add('resourcegroupname','')                                      # Name der Ressourcegruppe
$paramvnet.Add('location','westeurope')                                     # In welcher Region ist das VNET
$paramvnet.Add('netname','')                                                # Wie heisst das Netz
$paramvnet.Add('netaddressprefix','10.0.0.0/16')                            # Netzdefinition
$paramvnet.Add('privsubnetname','Private')                                  # Name des Subnets das wir nutzen werden
$paramvnet.Add('privsubnetaddressprefix','10.0.10.0/24')                    # Range des Subnets


# VM Parameter

$paramvm = @{}
	$paramvm.Add('location','westeurope')                                   # In welcher Region soll erstellt werden
	$paramvm.Add('resourcegroup','')                                        # Name der Ressourcegruppe
	$paramvm.Add('name','')                                                 # Name der VM
	$paramvm.Add('nsgname','')                                              # Name der Network Security Group
	$paramvm.Add('nicip','')                                                # IP Adresse. Falls leer wird DHCP genommen
	$paramvm.Add('nicname','')                                              # Name der Netzwerkkarte
	$paramvm.Add('size','Standard_DS3_v2')                                  # Grösse der VM
	$paramvm.Add('osdisk','')                                               # Name der OS Disk
	$paramvm.Add('storageaccounttype','StandardSSD_LRS')                    # Typ Storage auf dem die Diskfiles erstellt werden sollen
	$paramvm.Add('publishername','MicrosoftWindowsServer')                  # Publisher
	$paramvm.Add('offer','WindowsServer')                                   # Offering
	$paramvm.Add('sku','2016-Datacenter')                                   # Version, SKU