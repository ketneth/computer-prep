#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)][String]$logPath
)

function Add-LogMessage{
	param(
		[Parameter(MandaTory, Position=0)][String]$logPath,
		[Parameter(Mandatory, ValueFromPipeline)][String]$message
	)

    process{
        $Date = Get-Date -Format HH:MM:ss
        "$Date`t$message" | Out-File $logPath -Append -Encoding ascii
        Write-Verbose $message
    }

	<#
        .SYNOPSIS
        Add Message to LogFile.

        .DESCRIPTION
        Adds timestamp and Message to LogFile.
    #>
}

# Documents the bloatware removal start time.
"==Bloatware Removal Start==" | Add-LogMessage $logPath

# Recovering the device manufacturer.
$manufacturer = (Get-ComputerInfo -Property CsManufacturer).CsManufacturer

# Finds the exceptions associated with the computer's manufacturer.
# If none are found, the script quits.
switch($manufacturer){
	"HP"{$exceptions = "Realtek|Intel|Microsoft|Windows"}
	"DELL"{}
	"LENOVO"{}
	default{}
}

# Stops the script if no exceptions are found for the given manufacturer.
if($null -eq $exceptions){
	"ERROR`tUnsupported Manufacturer: $manufacturer" | Add-LogMessage $logPath
	"==Bloatware Removal End==" | Add-LogMessage $logPath
	return
}else{
	"Manufacturer found: $manufacturer", "Corresponding exceptions: $exceptions" | Add-LogMessage $logPath
	
	# Recovering matching applications.
	$bloatwareApps = Get-AppxPackage -AllUsers | Where-Object{$_.Name -notmatch $exceptions -and $_.Name -match $manufacturer}
	"$($bloatwareApps.Count) app(s) found.", "Attempting uninstall." | Add-LogMessage $logPath
	
	# Removing them from the current users.
	$bloatwareApps | Remove-AppxPackage -AllUsers | Out-File $logPath -Append
	
	# Removing them from the new users profile.
	$provisionedBloatware =  Get-AppxProvisionedPackage -Online | Where-Object{$_.DisplayName -match $manufacturer -and $_.DisplayName -notmatch $exceptions}
	"$($provisionedBloatware.Count) provisioned app(s) found.", "Attempting uninstall." | Add-LogMessage $logPath
	$provisionedBloatware | Remove-AppxProvisionedPackage -Online | Out-File $logPath -Append
	
	# Removing bloatware from the control panel applications.
	$retryCount = 0
	While($retryCount -lt 3 -or $retries){
		if($PSVersionTable.PSVersion.Major -eq 7){
			$softwares = Get-CimInstance -ClassName Win32_Product
		}else{
			$softwares = Get-WmiObject -ClassName Win32_Product
		}
		$soft = $softwares | Where-Object{$_.Vendor -match $manufacturer -and $_.Name -notmatch $exceptions}
		$retries = @()
		foreach($software in $soft){
			"Uninstalling: $($software.Name)" | Add-LogMessage $logPath
			$Temp = $software.Uninstall()
			if($Temp.ReturnValue){
				"Failed uninstalling, retrying." | Add-LogMessage $logPath
				$retries += $software
			}else{
				"Successfully uninstalled." | Add-LogMessage $logPath
			}
			$i++
		}
		$retryCount++
		if($retries){
			"Retrying for $($retries.Count) software(s), for $retryCount time(s)." | Add-LogMessage $logPath
		}
	}
	if(-not ($bloatwareApps -and $provisionedBloatware -and $soft)){
		"All bloatware removed" | Add-LogMessage $logPath
	}else{
		"Failed to remove all software.", "$($retries.Count) application(s) still present." | Add-LogMessage $logPath
		$retries.Name | Out-File $logPath -Append
	}
	"==Bloatware Removal End==" | Add-LogMessage
	Restart-Computer -Force
}
