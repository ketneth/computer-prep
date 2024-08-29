# Requires -RunAsAdministrator

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

# Imports the config file parameters.
[xml]$Config = Get-Content $PSScriptRoot\Config.xml

# Defines log file name.
$Serial = (wmic bios get serialnumber | Where-Object{$_})[1].Trim()
$LogPath = "$PSScriptRoot\logs\$Serial`_log.txt"

# Verifies if a corresponding file exists.
if(-not (Test-Path -Path $LogPath -PathType Leaf)){
    $Serial = $Serial.Replace(" ","_")
    $LogPath = "$PSScriptRoot\logs\$Serial`_log.txt"
    # Verifies again, replacing spaces by underscores.
    if(-not (Test-Path -Path $LogPath -PathType Leaf)){
        # Creates the file if it cannot be found.
        New-Item -Path $LogPath -Force
        "Origingal logfile missing. New one created." | Add-LogMessage $LogPath
    }
}

# Creates a startup script to restart the process after a reboot.
$Location = "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Restart.bat"
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
if(!(Test-Path $Location)){
	$Script | Out-File -FilePath $Location -Force
}

# Recovers the log file's contents.
$LogFile = Get-Content -Path $LogPath

<# Windows Updates #>
$WindowsUpdateEnd = $LogFile | Where-Object{$_ -match "[WindowsUpdate End]"}
if($Config.Settings.WindowsUpdate.Run -match "true" -and -not $WindowsUpdateEnd){
    & $PSScriptRoot\WindowsUPdate.ps1 -LogFile $LogPath -Auto
}

<# Bloatware Removal #>
$BloatwareRemovalEnd = $LogFile | Where-Object{$_ -match "[BloatwareRemover End]"}
if($Config.Settings.BloatwareRemoval.Run -match "true" -and -not $BloatwareRemovalEnd){
    & $PSScriptRoot\BloatwareRemoval.ps1 -LogFile $LogPath
}

<# Computer Rename #>
$ComputerRenameCheck = $LogFile | Where-Object{$_ -match "[Rename Skipped]|[Computer Renamed]"}
if($Config.Settings.ComputerRename.Run -match "true" -and -not $ComputerRenameCheck){
    $ComputerName = HOSTNAME
    $NewName = $Config.Settings.ComputerRename.NewName
    $NameCheck = $ComputerName -eq $NewName
    if(-not $NameCheck){
        if($NewName){
            "[Computer Renamed]" | Add-LogMessage $LogPath
            "Computer New Name: $NewName"
            Rename-Computer -NewName $Config.Settings.ComputerRename.NewName -Restart
        }else{
            $Check = $true
            while($Check){
                switch($NewName = Read-Host -Prompt "Please enter the new computer name. (Leave blank to skip)"){
                    {$_ -eq $ComputerName} {
                        Write-Host "This is already the given name of the device. Continuing with the script."
                        "[Rename Skipped] New name same as current one." | Add-LogMessage $LogPath
                        $Check = $false
                    }
                    {$null -ne $_} {
                        "[Computer Renamed] New name: $NewName" | Add-LogMessage $LogPath
                        Rename-Computer -NewName $NewName -Restart
                    }
                    default {$Check = $false}
                }
            }
        }
    }
}
