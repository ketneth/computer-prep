#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)][String]$LogFile
)

function Add-LogMessage{
	param(
		[Parameter(MandaTory, Position=0)][String]$logFile,
		[Parameter(Mandatory, ValueFromPipeline)][String]$message
	)

    process{
        $Date = Get-Date -Format HH:MM:ss
        "$Date`t$message" | Out-File $logFile -Append -Encoding ascii
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
"==BloatwareRemover Start==" | Add-LogMessage $LogFile

# Recovering the device manufacturer.
$Manufacturer = (Get-ComputerInfo -Property CsManufacturer).CsManufacturer

# Stops the script is the device manufacturer is not HP.
if($Manufacturer -notmatch "HP"){
	"ERROR`tUnsupported Manufacturer: $Manufacturer" | Add-LogMessage $LogFile
	"==BloatwareRemover End==" | Add-LogMessage $LogFile
	return
}

# Defines the exceptions for application removal.
$Exceptions = "Realtek|Intel|Microsoft|Windows"
"Configured Exceptions: $Exceptions" | Add-LogMessage $LogFile

# Recovering matching applications.
$BloatWareApps = Get-AppxPackage -AllUsers | Where-Object{$_.Name -notmatch $Exceptions -and $_.Name -match $Manufacturer}
"Configured Exceptions: $Exceptions" | Add-LogMessage $LogFile

# Removing them from the current users.
$BloatWareApps | Remove-AppxPackage -AllUsers | Out-Null

# Removing them from the new users profile.
Get-AppxProvisionedPackage -Online | Where-Object{$_.DisplayName -match $Manufacturer -and $_.DisplayName -notmatch $Exceptions} | Remove-AppxProvisionedPackage -Online

# Removing bloatware from the control panel applications.
$RetryCount = 0
While($RetryCount -lt 3 -or $Retries){
	$Soft = Get-WmiObject -Class Win32_Product | Where-Object{$_.Vendor -match $Manufacturer -and $_.Name -notmatch $Exceptions}
	$i = 0
	$iMax = $Soft.Count
	$Retries = @()
	foreach($SoftWare in $Soft){
		Write-Progress -Activity 'Uninstalling' -Status $Software.Name -PercentComplete (($i/$iMax)*100)
		"Uninstalling: $($Software.Name)" | Add-LogMessage $LogFile
		$Temp = $SoftWare.Uninstall()
		if($Temp.ReturnValue){
			$Retries += $SoftWare
		}
		$i++
	}
	$RetryCount++
}

if(!$Soft){
	"==BloatwareRemover End==" | Add-LogMessage $LogFile
}

Restart-Computer -Force