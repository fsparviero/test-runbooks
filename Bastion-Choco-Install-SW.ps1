<#
	Installs chocolatey if not installed
	Installs packages using chocolatey once installed
	Package selection changes based on hostname
#>

################### - Functions - ####################
function set-reg_keys{
  Param(
    #Parameter that can be modified to control which resource groups this runs against
    [Parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        HelpMessage="Enter one or more Windows registry setting as a hashtable object."
        )
    ]
    $RegSet = $null
  )
  if(!(($RegSet | Get-Member | Where-Object {$_.MemberType -like "NoteProperty"}).count -eq 6)){
		Write-Host "Cannot process item RegSet parameter requires psobject with 6 NoteProperty items: Path, Name, Type, Value, Hive, Comment" -ForegroundColor Red
    break
	}else{
    $Names = (($RegSet | Get-Member | Where-Object {$_.MemberType -like "NoteProperty"}).name)
    foreach($Name in $names){
      if(!(@("Path", "Name", "Type", "Value", "Hive", "Comment") -contains  $name)){
        Write-Host "Cannot process item RegSet parameter requires psobject with 6 NoteProperty items: Path, Name, Type, Value, Hive, Comment" -ForegroundColor Red
        break
      }else{Write-Verbose "Valid noteproperty field object found"}
    }
		
    switch($RegSet.Hive){
			{$_ -eq "HKEY_LOCAL_MACHINE"}{
        $Hive = "HKLM"
        Write-Verbose "Hive = HKLM"
      }
			{$_ -eq "HKEY_CURRENT_USER"}{
        $Hive = "HKCU"
        Write-Verbose "Hive = HKCU"
      }
			default {
        $Hive = $false
        Write-Host "Error invalid Hive type, should be either HKEY_LOCAL_MACHINE or HKEY_CURRENT_USER" -ForegroundColor Red
        break
      }
		}
		switch($RegSet.Type){
			{$_ -eq "REG_SZ"}{
        $Type = "String"
        Write-Verbose "Data Type = String"
        break
      }
			{$_ -eq "REG_EXPAND_SZ"}{
        $Type = "ExpandString"
        Write-Verbose "Data Type = ExpandString"
        break
      }
			{$_ -eq "REG_BINARY"}{
        $Type = "Binary"
        Write-Verbose "Data Type = Binary"
        break
      }
			{$_ -eq "REG_DWORD"}{
        $Type = "DWord"
        Write-Verbose "Data Type = DWord"
        break
      }
			{$_ -eq "REG_MULTI_SZ"}{
        $Type = "MultiString"
        Write-Verbose "Data Type = MultiString"
        break
      }
			{$_ -eq "REG_QWORD"}{
        $Type = "Qword"
        Write-Verbose "Data Type = QWord"
        break
      }
			default {
        $Type = $false
        Write-Host "Error invalid data type, should be one of REG_SZ, REG_EXPAND_SZ, REG_BINARY, REG_DWORD, REG_MULTI_SZ or REG_QWORD" -ForegroundColor Red        
        break
      }
		}
		if(($Hive -eq $false) -or ($Type -eq $false)){
			Write-Host "Error with type or hive specified, cannot continue" -Foregroundcolor Red
			break
		}
		[string]$Path = $RegSet.Path
    Write-Verbose "Looking for registry path $($Path)"
		[string]$Name = $RegSet.Name
    Write-Verbose "Looking for registry key $($Name)"
		$Value = $RegSet.Value
    Write-Verbose "Looking for key value $($Value)"
    #see if reg path works, create if not
    $pathitems = $Path.split("\")
    $CurrentPath = ""
    $ItemNumber = 0
    foreach($Item in $pathitems){
      if($ItemNumber -eq 0){
        $CurrentPath = $Item
      }else{
        $OldPath = $CurrentPath
        $CurrentPath = "$($CurrentPath)\$($Item)"
      }
      try{
        Write-Verbose "Testing $($Hive):\$($CurrentPath)"
        $testpath = Test-Path -path "$($Hive):\$($CurrentPath)" -erroraction stop
        if(!$testpath){
          Write-Host "Reg path $($Hive):\$($CurrentPath) not found, attempting to create $($Item) at $($Hive):\$($OldPath)" -ForegroundColor Green
          New-Item -Path "$($Hive):\$($OldPath)\" -Name $Item
        }
      }catch{
        Write-Host "Failed at $($Hive):\$($CurrentPath), attempting to create $($Item) at $($Hive):\$($OldPath)" -ForegroundColor Red
        New-Item -Path "$($Hive):\$($OldPath)\" -Name $Item
      } 
      $ItemNumber ++ 
    }

    try{
			#Get-Item -path "$($Hive):\$($Path)\$($Name)" -erroraction stop
			if((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name -eq $Value){
  			Write-Verbose "$($Name) is already set to $($Value), no further action required."
			}else{
				#handle null values
        if(($null -like $Value) -or ($Value -eq "")){
          Clear-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop
          #check result of actions
          if( ($null -like ((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name)) -or (((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name) -eq "")){
            Write-Verbose "$($Name) succesfully set to NULL, no further action required."
          }else{
            Write-Host "Error setting $($Hive):\$($Path)\$($Name) to NULL, please remediate." -Foregroundcolor Red
          }
        }else{
          Set-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -Value $Value -Type $Type
          #check result of actions
          if((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name -eq $Value){
            Write-Verbose "$($Name) succesfully set to $($Value), no further action required."
          }else{
            Write-Host "Error setting $($Hive):\$($Path)\$($Name) to $($Value), please remediate." -Foregroundcolor Red
          }
        }
			}
		}catch{

			Write-Host "Item $($Name) does not exist at $($Hive):\$($Path), attempting to create" -ForegroundColor Green
			#handle null values
			if(($null -like $RegSet.Value) -or ($RegSet.Value -eq "")){
			  try{
				  Clear-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop
  			}catch{
   			  $arguments = "add `"$($Hive)\$($Path)`" /f"
				  Start-Process reg.exe -ArgumentList $arguments -Wait

				  $arguments = "add `"$($Hive)\$($Path)`" /v $($Name) /t $($RegSet.Type) /ve /f"
				  Start-Process reg.exe -ArgumentList $arguments -Wait
        }
			}else{
				Set-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -Value $Value -Type $Type -ErrorAction Stop
			}
			
			try{
				if((Get-ItemProperty -Path "$($Hive):\$($Path)" -Name $Name -ErrorAction stop).$Name -eq $Value){
					Write-Verbose "$($Name) succesfully set to $($Value), no further action required."
				}else{
					Write-Host "Error setting $($Hive):\$($Path)\$($Name) to $($Value), please remediate." -Foregroundcolor Red
				}			
			}catch{
				$arguments = "add `"$($Hive)\$($Path)`" /f"
				Start-Process reg.exe -ArgumentList $arguments -Wait

				$arguments = "add `"$($Hive)\$($Path)`" /v $($Name) /t $($RegSet.Type) /d $($Value) /f"
				Start-Process reg.exe -ArgumentList $arguments -Wait
			}
		}		
	}
}

################### - End of Functions - ####################

#disable defender to allow installs to work
try{Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction stop}catch{exit 1}

#check chocolatey installed
try{$ChocoInstalled = Get-ChildItem "C:\ProgramData\chocolatey\choco.exe" -erroraction stop}catch{$ChocoInstalled = $false}
if($ChocoInstalled){
  #ensure chocolatey is latest version
  choco upgrade chocolatey -y
}else{
	Set-ExecutionPolicy Bypass -Scope Process -Force; invoke-expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

#configure chocolatey packages to be installed on every vm
$packages = @("googlechrome","git","vscode","postman","powershell-core","azure-cli","microsoftazurestorageexplorer","7zip","filezilla","sumatrapdf","putty","azure-data-studio","microsoft-edge")

#configure chocolatey packages to be installed on specific use-case vms
switch( hostname ){
	{$_ -match "data"}{
		write-host "data vm detected, selecting software" -Foregroundcolor Green
		#Data team software
			$packages += "sql-server-management-studio"
			$packages += "mongodb-compass"
	}
	{$_ -match "qa"}{
		write-host "qa vm detected, selecting software" -Foregroundcolor Green
		#QA team software
			$packages += "db-visualizer"
			$packages += "intellijidea-community"
			$packages += "maven"
			$packages += "mongodb-compass"
	}
	{$_ -match "web"}{
		write-host "web vm detected, selecting software" -Foregroundcolor Green
    #install IIS minimal
    Install-WindowsFeature -name Web-Server -IncludeManagementTools -erroraction silentlycontinue -verbose
		#Web/API team software
			$packages += "stunnel"
			$packages += "maven"
			$packages += "sql-server-management-studio"
			$packages += "mongodb-compass"
			$packages += "dotnet"
			$packages += "dotnetcore"
		#redis cli
		$url = "https://github.com/microsoftarchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi"
		$fileName = $url.split("/")[-1]
		$Outfile = "$($env:TEMP)\$($fileName)"
		Write-Host "Downloading $($fileName)..." -Foregroundcolor Yellow
		Invoke-WebRequest -Uri $url -Outfile $Outfile
		if(Test-Path $Outfile){
		  Write-Host "Installing $($fileName)..." -Foregroundcolor Yellow
		 $arguments = @("/I $($Outfile)", "/quiet")
		 Start-Process msiexec.exe -ArgumentList $arguments -Wait
		}
	}
	{$_ -match "infra"}{
		write-host "Infra vm detected, selecting software" -Foregroundcolor Green
		#Infra team software
		$packages += "notepadplusplus"
	}
}

#install or upgrade all the selected packages

foreach($package in $packages){
	$arguments = @("upgrade $($package) -y")
	Start-Process choco.exe -ArgumentList $arguments -Wait
}

#install windows subsystem for linux
Write-Host "Checking if Windows Linux subsystem is installed" -Foregroundcolor green
if((wsl --status).count -gt 50 ){
  Write-Host "Installing Windows subsystem for Linux" -Foregroundcolor Yellow
  wsl --install
}else{
  Write-Host "Windows subsystem for Linux already installed" -Foregroundcolor green
}

#add registry entry to show which software was installed
$RegSettings = @{
  "Comment" = "List of software installed by Chocolatey on this VM";
  "Name" = "$(get-date)";
  "Value" = "'$($packages -join ", ")'";
  "Path" = "Software\\UHG\\ChocoInstalls";
  "Hive" = "HKEY_LOCAL_MACHINE";
  "Type" = "REG_SZ"
}
set-reg_keys -RegSet @($RegSettings|convertto-json|convertfrom-json)

#re-enable defender
try{
  Set-MpPreference -ScanParameters FullScan -ScanScheduleDay Everyday -DisableIntrusionPreventionSystem 0 -DisableRealtimeMonitoring 0 -DisableEmailScanning 0 -DisableRemovableDriveScanning 0 -EnableNetworkProtection Enabled -EnableControlledFolderAccess Enabled -ScanScheduleTime 12:00 -RemediationScheduleTime 13:00 -SignatureScheduleTime 11:00  -ExclusionPath "$($env:USERPROFILE)\Documents\PowerShell" -verbose -ErrorAction stop
}catch{
  exit 1
}

#vulnerability
get-item "C:\Program Files\7-Zip\7-zip.chm"|Remove-Item -force

#reregister changes with defender qualys scan
$arguments = "ADD HKLM\SOFTWARE\Qualys\QualysAgent\ScanOnDemand\Vulnerability /v ScanOnDemand /t REG_DWORD /d 1 /f"
try{Start-Process reg.exe -ArgumentList $arguments -Wait -ErrorAction stop}catch{exit 1}

Exit 0
