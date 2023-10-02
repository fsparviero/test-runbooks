# Import the modules
Import-module 'az.accounts'
Import-module 'az.compute'

# Connect to Azure with the System Managed Identity
Connect-AzAccount -Identity

write-host "Login complete"

# Starting the all non prod vms 
write-host "starting vms in the rg-US6122593-pdp-test resource group " 
Get-AzVm -ResourceGroupName 'rg-bastion-vms-preprod' |Start-AzVM -nowait
#checking on the vms status 
write-host "Checking on the status of the virtual machines" 
Get-AzVm -ResourceGroupName 'rg-bastion-vms-preprod' -status |format-table
