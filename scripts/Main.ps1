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
$ParentFolder = Split-Path $PSScriptRoot -Parent
$Config = Get-Content -Path $ParentFolder\Config.json -Raw | ConvertFrom-Json

# Defines log file name.
$Serial = (wmic bios get serialnumber | Where-Object{$_})[1].Trim()
$LogPath = "$PSScriptRoot\$Serial`_log.txt"

# Verifies if a corresponding file exists.
if(-not (Test-Path -Path $LogPath -PathType Leaf)){
    $Serial = $Serial.Replace(" ","_")
    $LogPath = "$PSScriptRoot\$Serial`_log.txt"
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
if($Config.WindowsUpdate -match "true" -and -not $WindowsUpdateEnd){
    & $PSScriptRoot\WindowsUPdate.ps1 -LogFile $LogPath -Auto
}

<# Bloatware Removal #>
$BloatwareRemovalEnd = $LogFile | Where-Object{$_ -match "[BloatwareRemover End]"}
if($Config.BloatwareRemoval -and -not $BloatwareRemovalEnd){
    & $PSScriptRoot\BloatwareRemoval.ps1 -LogFile $LogPath
}

<# Computer Rename #>
$ComputerRenameCheck = $LogFile | Where-Object{$_ -match "[Rename Skipped]|[Computer Renamed]"}
if($Config.ComputerRename.Run -and -not $ComputerRenameCheck){
    $ComputerName = HOSTNAME
    $NewName = $Config.ComputerRename.NewName
    if(-not $ComputerName -eq $NewName){
        if($NewName){
            "[Computer Renamed]" | Add-LogMessage $LogPath
            "Computer New Name: $NewName"
            Rename-Computer -NewName $Config.ComputerRename.NewName -Restart
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

<# UserSettings #>
$UserSettingsCheck = $LogFile | Where-Object{$_ -match "[UserSettings End]"}
if($Config.UserSettings | Where-Object{$_} -and -not $UserSettingsCheck){
    "[UserSettings Start]" | Add-LogMessage $LogPath
    # Loads the registry profile.
    REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
    if($Config.UserSettings.DesktopCleanup){
        Remove-Item -Path $Env:USERPROFILE\Desktop\ -Filter "*.lnk"
        "User Desktop Cleaned" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.PublicDesktopCleanup){
        Remove-Item -Path $Env:PUBLIC\Desktop\ -Filter "*.lnk"
        "Public Desktop Cleaned" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.RemoveTaskView){
        New-ItemProperty -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword -Force
        "Taskview Removed" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.RemoveWidgets){
        New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword -Force
        "Widgets Removed" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.RemoveChat){
        New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword -Force
        "Chat Icon Removed" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.MoveStartLeft){
        New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword -Force
        "Taskbar Moved to the Left" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.RemoveSearch){
        $Path = "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Search"
        if(-not (Test-Path -Path $Path)){
            New-Item -Path $Path -Force
            "Registry key missing. Created: $Path"
        }
        New-ItemProperty -Path $Path -Value "0" -PropertyType Dword -Force
        "Search Icon Removed" | Add-LogMessage $LogPath
    }
    if($Config.UserSettings.StartMorePins){
        New-ItemProperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "1" -PropertyType Dword -Force
        "More Pinning space added to Start menu" | Add-LogMessage $LogPath
    }
    "[UserSettings End]" | Add-LogMessage $LogPath
}

<# LocalAdminPassword #>
$LocalAdminPasswordCheck = $LogFile | Where-Object{$_ -match "[LocalAdminPassword End]"}
if($Config.LocalAdminPassword -and -not $LocalAdminPasswordCheck){
    "[LocalAdminPassword Start]" | Add-LogMessage $LogPath
    $OriginCheck = $LogFile | Where-Object{$_ -match "SourceLocation="}
    if($OriginCheck){

    }
    "[LocalAdminPassword End]" | Add-LogMessage $LogPath
}

<# Cleanup #>
if($Config.Cleanup -and (Test-Parth -Path "C:\Temp\prep\")){
    
}