# Import the modules
Import-module 'az.accounts'
Import-module 'az.compute'

# Connect to Azure with the System Managed Identity
Connect-AzAccount -Identity

write-host "Login complete"

# Starting the all non prod vms 
#get's vms which are not running

$VMsToMonitor = (Get-Azvm -status -ResourceGroupName "rg-bastion-vms-uat") | Where-Object{$_.PowerState -notlike "VM running"}

#issues start to non running vms

$VMsToMonitor | Where-Object{$_.PowerState -notlike "VM running"}|Start-AzVM -nowait

$Monitoring = $VMsToMonitor.count

#monitor vms until started

DO{

  foreach($AZVM in $VMsToMonitor){

	  Write-Host "Getting Status of VM $($AZVM.Name)" -foregroundcolor Yellow

	  $PowerState = ($AZVM | Get-Azvm -status).Statuses[1].DisplayStatus

	  switch($PowerState){

		"VM running" {

			Write-Host "$($AZVM.Name): status $($PowerState)" -foregroundcolor Green

			$Monitoring = ($Monitoring - 1)				

		}

		Default {

			Write-Host "$($AZVM.Name): status $($PowerState)" -foregroundcolor Red

		}

	  }

  }

    Write-Host "Wait 10 seconds" -foregroundcolor Yellow

	start-sleep -seconds 10

}While($Monitoring -gt 0)


