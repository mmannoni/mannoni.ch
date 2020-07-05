<#
.SYNOPSIS
  Change NSG Rules

.DESCRIPTION
  Change every NSG in a tenant

.INPUTS
  <None>

.OUTPUTS
  <None>

.NOTES
  Version:        <1.0>
  Author:         Marco Mannoni
  Creation Date:  21.05.2020
  Purpose/Change: <Initial script development>
  
.CHANGES


#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$ErrorActionPreference = 'Stop'

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Declaring tenant and subscription ID

$subscriptionId = '***'

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Connect to Azure and set context to target tenant
Connect-AzAccount
$azcontext = Get-AzSubscription -SubscriptionId $subscriptionId
Set-AzContext $azcontext

# Query all NSGs
$nsgs = Get-AzNetworkSecurityGroup | Where-Object Name -Match '^***-***-***'

# Define NSG Rules
$nsgRule1 = New-AzNetworkSecurityRuleConfig -Name '***RuleNameHere***' `
    -Description '***RuleDescriptionHere***' `
    -Access Allow `
    -Protocol * `
    -SourcePortRange * `
    -DestinationPortRange * `
    -SourceAddressPrefix * `
    -Direction Inbound `
    -Priority 100 `
    -DestinationAddressPrefix *

$nsgRule2 = New-AzNetworkSecurityRuleConfig -Name '***RuleNameHere***' `
    -Description '***RuleDescriptionHere***' `
    -Access Allow `
    -Protocol * `
    -SourcePortRange * `
    -DestinationPortRange * `
    -SourceAddressPrefix * `
    -Direction Outbound `
    -Priority 100 `
    -DestinationAddressPrefix *
# Update the NSGs
foreach ($nsg in $nsgs) {
        try {
            Write-Host "Updating Network Security Groups" -ForegroundColor Blue
            Get-AzNetworkSecurityGroup -Name $nsg.name -ResourceGroupName $nsg.resourcegroupname |Set-AzNetworkSecurityRuleConfig -Name $nsgRule1.Name -Description $nsgRule1.Description `
            -Access $nsgRule1.access -Protocol $nsgRule1.Protocol -SourcePortRange $nsgRule1.SourcePortRange -DestinationPortRange $nsgRule1.DestinationPortRange `
            -SourceAddressPrefix $nsgRule1.SourceAddressPrefix -Direction $nsgRule1.Direction -Priority $nsgRule1.Priority -DestinationAddressPrefix $nsgRule1.DestinationAddressPrefix |
            Set-AzNetworkSecurityGroup
            Get-AzNetworkSecurityGroup -Name $nsg.name -ResourceGroupName $nsg.resourcegroupname |Set-AzNetworkSecurityRuleConfig -Name $nsgRule2.Name -Description $nsgRule2.Description `
            -Access $nsgRule2.access -Protocol $nsgRule2.Protocol -SourcePortRange $nsgRule2.SourcePortRange -DestinationPortRange $nsgRule2.DestinationPortRange `
            -SourceAddressPrefix $nsgRule2.SourceAddressPrefix -Direction $nsgRule2.Direction -Priority $nsgRule2.Priority -DestinationAddressPrefix $nsgRule2.DestinationAddressPrefix |
            Set-AzNetworkSecurityGroup
        }
    catch {
        Write-Error -Message "Failed to update Network Security Groups"
    }
}
Write-Host "Successfully finished script execution." -ForegroundColor Green

