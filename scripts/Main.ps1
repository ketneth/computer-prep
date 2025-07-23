#Requires -RunAsAdministrator

function Add-LogMessage{
	param(
		[Parameter(MandaTory, Position=0)][String]$logFile,
		[Parameter(Mandatory, ValueFromPipeline)][String]$Message
	)

    process{
	$Date = Get-Date -Format HH:MM:ss
        "$Date`t$Message" | Out-File $logFile -Append -Encoding ascii
    Write-Verbose $Message
    }

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
$LogPath = "$ParentFolder\$Serial`_log.txt"

# Verifies if a corresponding file exists.
if(-not (Test-Path -Path $LogPath -PathType Leaf)){
    $Serial = $Serial.Replace(" ","_")
    $LogPath = "$ParentFolder\$Serial`_log.txt"
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
    goto End
)
:Continue
powershell.exe -NoLogo -NoExit -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
:End
"
if(!(Test-Path $Location)){
	$Script | Out-File -FilePath $Location -Encoding ascii -Force
    Restart-Computer -Force
}

# Changes the computer's execution policy.
if((Get-ExecutionPolicy -Scope LocalMachine) -notmatch "RemoteSigned"){
    "Changed device's ExecutionPolicy to 'RemoteSigned'" | Add-LogMessage $LogPath
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Restart-Computer -Force
}

# Recovers the log file's contents.
$LogFile = Get-Content -Path $LogPath

<# Windows Updates #>
$WindowsUpdateEnd = $LogFile | Where-Object{$_ -match "\[WindowsUpdate End\]"}
if($Config.WindowsUpdate -match "true" -and -not $WindowsUpdateEnd){
    & $PSScriptRoot\WindowsUPdate.ps1 -LogFile $LogPath -Auto
}

<# Bloatware Removal #>
$BloatwareRemovalEnd = $LogFile | Where-Object{$_ -match "\[BloatwareRemover End\]"}
if($Config.BloatwareRemoval -and -not $BloatwareRemovalEnd){
    & $PSScriptRoot\BloatwareRemover.ps1 -LogFile $LogPath
}

<# App Install #>
$Installers = Get-ChildItem -Path $ParentFolder\apps\*.* -Exclude "Setup.csv"
$InstallCheck = $LogFile | Where-Object{$_ -match "\[AppSetup End\]"}
if($Installers -and -not $InstallCheck){
    & $PSScriptRoot\AppSetup.ps1 -LogFile $LogPath
}

<# Computer Rename #>
$ComputerRenameCheck = $LogFile | Where-Object{$_ -match "\[Rename Skipped\]|\[Computer Renamed\]"}
if($Config.ComputerRename.Run -and -not $ComputerRenameCheck){
    $ComputerName = $env:COMPUTERNAME
    $NewName = $Config.ComputerRename.NewName
    if($NewName){
        if(-not $ComputerName -eq $NewName){
            "[Computer Renamed]" | Add-LogMessage $LogPath
            "Computer New Name: $NewName" | Add-LogMessage $LogPath
            Rename-Computer -NewName $Config.ComputerRename.NewName -Restart
        }
    }else{
        $Check = $true
        while($Check){
            switch(Read-Host -Prompt "Please enter the new computer name. (Leave blank to skip)"){
                {$_ -eq $ComputerName} {
                    Write-Host "This is already the given name of the device. Continuing with the script."
                    "[Renamed Skipped]" | Add-LogMessage $LogPath
                    $Check = $false
                }
                {$_ -ne ''} {
                    Write-Host "Computer renamed: $_"
                    "[Computer Renamed]" | Add-LogMessage $LogPath
                    "Computer New Name: $NewName" | Add-LogMessage $LogPath
                    $Check = $false
                    Rename-Computer -NewName $_ -Restart -Force
                }
                default {
                    Write-Host 'No name given.'
                    "[Renamed Skipped]" | Add-LogMessage $LogPath
                    $Check = $false
                }
            }
        }
    }
}

<# UserSettings #>
$UserSettingsCheck = $LogFile | Where-Object{$_ -match "\[UserSettings End\]"}
if($Config.UserSettings -and -not $UserSettingsCheck){
    "[UserSettings Start]" | Add-LogMessage $LogPath
    # Recovers the registry changes.
    $Registries = $Config.UserSettings.Registry
    # Prepares the environment.
    if($Registries.Path | Where-Object{$_ -match "HKU:\\"}){
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    }
    if($Registries.Path | Where-Object{$_ -match "HKLM:\\Default"}){
        REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
    }
    if($Config.UserSettings.RunForExistingUsers){
        $UserRegistries = foreach($Registry in $Registries){
            if($Registry.Path -match "HKLM:\\Default"){
                $Registry.Path = $Registry.Path.Replace("HKLM:\Default","HKCU:")
                $Registry
            }else{
                continue
            }
        }
        $Registries += $UserRegistries
    }
    foreach($Registry in $Registries){
        if(-not $Registry.Enabled){
            continue
        }
        $params = @{
            Path = $Registry.Path
            ErrorAction = 'SilentlyContinue'
        }
        # Verifies if the Path exists.
        if(Test-Path @params){
            $params["Name"] = $Registry.Name
            # Verifies if the property exists.
            if(Get-ItemProperty @params){
                $params["Value"] = $Registry.Value
                Set-ItemProperty @params
                "$($Registry.DisplayName): Registry value changed" | Add-LogMessage $LogPath
                "$($Registry.Path) - $($Registry.Name) - $($Registry.Value)" | Add-LogMessage $LogPath
            }else{
                $params["Value"] = $Registry.Value
                $params["PropertyType"] = $Registry.PropertyType
                New-ItemProperty @params -Force
                "$($Registry.DisplayName): Registry value created" | Add-LogMessage $LogPath
                "$($Registry.Path) - $($Registry.Name) - $($Registry.Value)" | Add-LogMessage $LogPath
            }
        }else{
            New-Item @params -Force
            "$($Registry.DisplayName): Registry path created" | Add-LogMessage $LogPath
            $params["Value"] = $Registry.Value
            $params["PropertyType"] = $Registry.PropertyType
            New-ItemProperty @params -Force
            "$($Registry.DisplayName): Registry value created" | Add-LogMessage $LogPath
            "$($Registry.Path) - $($Registry.Name) - $($Registry.Value)" | Add-LogMessage $LogPath
        }
    }
    "[UserSettings End]" | Add-LogMessage $LogPath
}

<# LocalAdminPassword #>
$LocalAdminPasswordCheck = $LogFile | Where-Object{$_ -match "\[LocalAdminPassword End\]"}
if($Config.LocalAdminPassword -and -not $LocalAdminPasswordCheck){
    # Generates the new password.
    "[LocalAdminPassword Start]" | Add-LogMessage $LogPath
    $Check = $false
    $NewPassword = while(-not $Check){
        $Characters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789'
        $Symbols = '!@#$%&*?'
        $Template = -join (1..10 | ForEach-Object {Get-Random -InputObject $characters.ToCharArray()})
        $Template += -join (1..2 | ForEach-Object {Get-Random -InputObject $Symbols.ToCharArray()})
        if($Template -cmatch "[A-Z]" -and $Template -cmatch "[a-z]" -and $Template -match "\d"){
            foreach($Symbol in $Symbols.ToCharArray()){
                if($Template -match "\$Symbol"){
                    Write-Host $Symbol
                    $Template
                    $Check = $true
                    break
                }
            }
        }else{
            Write-Host $Template
        }
    }
    # Prepares the ItGlue password import file.
    $Username = WHOAMI
    $User = $Username.Split("\")[1]
    $Password = @{
        organization = ""
        name = $Username.Replace("\"," - ")
        password_category = "Local Admin"
        username = $Username
        password = $NewPassword
        url = ""
        notes = ""
    }
    $PswFile = "$env:USERPROFILE\Desktop\Password_$env:COMPUTERNAME.csv"
    [PSCustomObject]$Password | Export-Csv -NoTypeInformation -NoClobber -Delimiter ',' -Path $PswFile
    # Remove quotes from the CSV file.
    $Temp = Get-Content -Path $PswFile
    $Temp | ForEach-Object{$_.Replace('","',',').TrimStart('"').TrimEnd('"')} | Out-File -FilePath $PswFile
    "Password documentation file created" | Add-LogMessage $LogPath
    # Verifies if the source disk is avilable.
    $Origin = ($LogFile | Where-Object{$_ -match "SourceLocation="}).Split('=')[1]
    if(Test-Path -Path $Origin){
        # Copies the password file to the source disk.
        Copy-Item -Path $PswFile -Destination $Origin
        "Password file copied to source directory" | Add-LogMessage $LogPath
    }else{
        # Source disk cannot be found stores the password
        # documentation file on the desktop.
        Copy-Item -Path $PswFile -Destination "$Env:USERPROFILE\Desktop"
        "Source disk could not be reached." | Add-LogMessage $LogPath
        "Password file stored on the user's desktop." | Add-LogMessage $LogPath
    }
    # Creates a script to change the current user's password
    # and stores it on the desktop.
    $ScriptPath = "$Env:USERPROFILE\Desktop\PswdChange.bat"
    $Script = "@echo off
    echo This script will change the curen't user's password.
    echo Make sure to recover the file prior to running this command.
    pause
    NET USER $User $NewPassword" 
    $Script | Out-File -FilePath $ScriptPath -Encoding utf8 -Force
    "Password change script stored on desktop." | Add-LogMessage $LogPath
    "[LocalAdminPassword End]" | Add-LogMessage $LogPath
}

<# Cleanup #>
$CleanupCheck = $LogFile | Where-Object{$_ -match "\[Cleanup End\]"}
if($Config.Cleanup -and -not $CleanupCheck){
    "[Cleanup Start]" | Add-LogMessage $LogPath
    # Copies the password CSV document to the desktop
    # in case some are still present in the prep folder.
    $PasswordCheck = Get-ChildItem -Path "$ParentFolder\Password*.csv" -Recurse
    if($PasswordCheck){
        $PasswordCheck | Copy-Item -Destination $Env:USERPROFILE\Desktop
    }
    # Removes existing shortcuts from the desktop.
    if($Config.Cleanup.DesktopCleanup){
        Remove-Item -Path "$Env:USERPROFILE\Desktop\*.lnk" -Force
        "Cleaned user desktop" | Add-LogMessage $LogPath
    }
    # Removes existing shortcuts from the public desktop.
    if($Config.Cleanup.PublicDesktopCleanup){
        Remove-Item -Path "$env:PUBLIC\Desktop\*.lnk" -Force
        "Cleaned Public desktop" | Add-LogMessage $LogPath
    }
    if($Config.Cleanup.LogBackup){
        # Verifies if the source disk can be contacted.
        $Origin = ($LogFile | Where-Object{$_ -match "SourceLocation="}).Split('=')[1]
        $OriginCheck = Test-Path $Origin
        if(-not $OriginCheck){
            "Source location not detected. Waiting for reconnect." | Add-LogMessage $LogPath
            while(-not $OriginCheck){
                # Stops the script untill the disc is reachable.
                Read-Host "Please connect the source disk before continuing: $Origin"
                $OriginCheck = Test-Path $Origin
            }
        }
        # Copies the logs to the source disk's log folder.
        $LogFolder = "$Origin`Logs"
        if(-not (Test-Path -Path $LogFolder)){
            New-Item -Path $LogFolder -ItemType Directory
            "Log Folder not found on source disk. New log folder created." | Add-LogMessage $LogPath
        }
        Copy-Item -Path $LogPath -Destination $LogFolder
        "Log files copied to the source disk: $(Split-Path -Path $LogPath -Leaf)" | Add-LogMessage $LogPath
    }
    if($Config.Cleanup.ScriptFolderRemoval){
        # Prepares the task of removing the prep folder.
        $params = @{
            Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
            Name = "!CleanupFolder"
            PropertyType = "String"
            Value = "CMD /C RD /S /Q C:\Temp\prep"
            Force = $true
        }
        New-ItemProperty @params
        "RunOnce task created." | Add-LogMessage $LogPath
    }
    if($Config.Cleanup.StartupScriptRemoval){
        # Removes the startup script.
        Remove-Item -Path "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Restart.bat"
        "Restart script removed." | Add-LogMessage $LogPath
    }
    if($Config.Cleanup.EnableUA){
        # Re-enables UAC.
        $params = @{
            Path = "HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            Name = "EnableLUA"
            Value = 1
            Force = $true
        }
        Set-ItemProperty @params
        "UAC re-enabled" | Add-LogMessage $LogPath
    }
    "[Cleanup End]" | Add-LogMessage $LogPath
}