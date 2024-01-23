# Import the modules
Import-module 'az.accounts'
Import-module 'az.compute'

# Connect to Azure with the System Managed Identity
Connect-AzAccount -Identity

write-host "Login complete"

$ResourceGroupName = "rg-bastion-vms-dev2"

write-host "Getting vm's"
$AZVMs = Get-Azvm -ResourceGroupName $ResourceGroupName
 
 
#run local script on selected AZ running VM's
Write-Host "Submitting command to run on Azure VM's" -foregroundcolor Yellow
$AZVMs|ForEach-Object -Parallel {
  Invoke-AzVMRunCommand -ResourceGroupName $_.ResourceGroupName -Name $_.Name -CommandId 'RunPowerShellScript' -ScriptString "choco.exe update all -y -i" -asjob | out-null
}
#check scripts complete
 
 
$Monitoring = $AZVMs.count
#Track events
$TrackEvents = @()
DO{
  foreach($AZVM in $AZVMs){
    Write-Host "Getting Status of VM $($AZVM.Name)" -foregroundcolor Yellow
    $DisplayStatus = ($AZVM | Get-Azvm -status).Statuses[0].DisplayStatus
    switch($DisplayStatus){
    "Updating" {
      Write-Host "$($AZVM.Name): status $($DisplayStatus)" -foregroundcolor Red
    }
    "Provisioning succeeded" {
      Write-Host "$($AZVM.Name): status $($DisplayStatus)" -foregroundcolor Green
      $Monitoring = ($Monitoring - 1)
    }
    default {Write-Host "$($AZVM.Name): status $($DisplayStatus)" -foregroundcolor Yellow}
    }
  }
  start-sleep -seconds 3
}While($Monitoring -gt 0)