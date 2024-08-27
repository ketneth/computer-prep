#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)][String]$LogFile
)

function Add-LogMessage{
	param(
		[Parameter(MandaTory, Position=0)][String]$LogFile,
		[Parameter(Mandatory, ValueFromPipeline)][String]$Message
	)
	$Date = Get-Date -Format HH:MM:ss
	"$Date`t$Message" | Out-File $LogFile -Append

	<#
        .SYNOPSIS
        Add Message to LogFile.

        .DESCRIPTION
        Adds timestamp and Message to LogFile.
    #>
}

# Documents the bloatware removal start time.
"[BloatwareRemover Start]" | Add-LogMessage $LogFile

# Recovering the device manufacturer.
$Manufacturer = (Get-ComputerInfo -Property CsManufacturer).CsManufacturer

# Stops the script is the device manufacturer is not HP.
if($Manufacturer -notmatch "HP"){
	"ERROR`tUnsupported Manufacturer: $Manufacturer" | Add-LogMessage $LogFile
	"[BloatwareRemover End]" | Add-LogMessage $LogFile
	return
}

# Location of the startup script.
$Location = "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Restart.bat"

# Contents of the startup script.
$Script = "@echo off
REM Verifies if the script is running as admin.
net session >nul 2>&1
if %errorLevel% == 0 (
	goto Continue
) else (
	REM Restarts the script as admin.
	powershell -command `"Start-Process %~dpnx0 -Verb runas`"
)
powershell.exe -NoLogo -NoExit -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
"

# Creation of of the startup script.
if(!(Test-Path $Location)){
	$SCript | Out-File -FilePath $Location -Force
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
	"[BloatwareRemover End]" | Add-LogMessage $LogFile
	Remove-Item $Location
}

Restart-Computer