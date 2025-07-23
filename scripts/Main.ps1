#Requires -RunAsAdministrator

<#
    ::Functions::
#>

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

<#
    ::Log file definition and creation::
#>

# Imports the config file parameters.
if($PSScriptRoot){
    $parentFolder = Split-Path $PSScriptRoot -Parent
}else{
    $parentFolder = (Get-Location).Path
}
$config = Get-Content -Path $parentFolder\Config.json -Raw | ConvertFrom-Json

# Defines log file name.
# Replacing possible spaces in the serial number with underscores.
if($PSVersionTable.PSVersion.Major -eq 7){
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
}else{
    $serialNumber = (Get-WmiObject -ClassName Win32_BIOS).SerialNumber
}
$serialNumber = $serialNumber.Replace(' ','_')
$logPath = "$parentFolder\$serialNumber`_log.txt"

# Creates the log file if not present.
# Documents script start time.
if(Test-Path -Path $logPath){
    "|:Script Start:|" | Add-LogMessage $logPath
}else{
    New-Item -Path $logPath -Force
    "|:Script Start:|", "ERROR`tLog file missing.", "New log file created: $logPath" | Add-LogMessage $logPath
}

<#
    ::Reboot script definition::
#>

# Creates a startup script and restarts the device.
$location = "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Restart.bat"
if(-not (Test-Path $location)){
    $script = "@echo off",
    "REM Verifies if the script is running as admin.",
    "net session >nul 2>&1",
    "if %errorLevel% == 0 (",
    "goto Continue",
    ") else (",
    "REM Restarts the script as admin.",
    "powershell -command `"Start-Process %~dpnx0 -Verb runas`"",
    "goto End",
    ")",
    ":Continue",
    "powershell.exe -NoLogo -NoExit -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath",
    ":End"
	$script | Out-File -FilePath $location -Encoding ascii -Force
    "ERROR`tRestart script missing.", "Restart script created: $location", "Restarting device." | Add-LogMessage $logPath
    Restart-Computer -Force
}

<#
    ::Environment definition::
#>

# Changes the computer's execution policy.
if((Get-ExecutionPolicy -Scope LocalMachine) -notmatch "RemoteSigned"){
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    "PowerShell execution policy changed to: RemoteSigned" | Add-LogMessage $logPath
}

# Changes the security protocol.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Defining the package provider.
if(-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)){
    "Package provider missing.", "Installing package: NuGet" | Add-LogMessage $logPath
    Install-PackageProvider -Name NuGet -Force
}

# Recovers the log file's contents.
$logFile = Get-Content -Path $logPath

<#
    ::Windows update::
#>

# Checking windows update run status.
$windowsUpdateEnd = $logFile | Where-Object{$_ -match "==Windows Update End=="}
if($config.WindowsUpdate -and -not $windowsUpdateEnd){
    "==Windows Update Start==" | Add-LogMessage $logPath
    # Installs module if missing.
    if(-not (Get-Module -Name PSWindowsUpdate -ListAvailable -ErrorAction SilentlyContinue)){
        "PowerShell module missing.", "Installing module: PSWindowsUpdate" | Add-LogMessage $logPath
        Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
    }
    # Update installation.
    $continue = $true
    $tries = 1
    $installedUpdates = @()
    while($continue -and $tries -lt 4){
        'Checking updates.' | Add-LogMessage $logPath
        Get-WindowsUpdate -IgnoreReboot -OutVariable availableUpdates | Out-File $logPath -Append
        if(-not $availableUpdates){
            'No updates found.' | Add-LogMessage $logPath
            break
        }
        $updateTest = Compare-Object -ReferenceObject $installedUpdates -DifferenceObject $availableUpdates.Title -IncludeEqual
        if($updateTest.SideIndicator -contains '=>'){
            'Installing updates.' | Add-LogMessage $logPath
            Install-WindowsUpdate -AcceptAll -IgnoreReboot -OutVariable installResult | Out-File $logPath -Append
            if($installResult.RebootRequired -contains 'True'){
                Restart-Computer -Force
            }
        }else{
            $continue = $false
        }
        $installedUpdates += ($installResult | Where-Object{$_.Result -ne 'Failed'}).Title
        if($installResult.Result -contains 'Failed'){
            $tries++
            if($tries -eq 3){
                "ERROR`tFailed to install updates 3 times." | Add-LogMessage $logPath
            }
        }
    }
    "==Windows Update End==" | Add-LogMessage $logPath
}

<# Bloatware Removal #>
$bloatwareRemovalEnd = $logFile | Where-Object{$_ -match "==BloatwareRemover End=="}
if($config.BloatwareRemoval -and -not $bloatwareRemovalEnd){
    & $PSScriptRoot\BloatwareRemover.ps1 -LogFile $logPath
}

<# App Install #>
$Installers = Get-ChildItem -Path $parentFolder\apps\*.* -Exclude "Setup.csv"
$InstallCheck = $logFile | Where-Object{$_ -match "==AppSetup End=="}
if($Installers -and -not $InstallCheck){
    & $PSScriptRoot\AppSetup.ps1 -LogFile $logPath
}

<# Computer Rename #>
$ComputerRenameCheck = $logFile | Where-Object{$_ -match "==Rename Skipped==|==Computer Renamed=="}
if($config.ComputerRename.Run -and -not $ComputerRenameCheck){
    $ComputerName = $env:COMPUTERNAME
    $NewName = $config.ComputerRename.NewName
    if($NewName){
        if(-not $ComputerName -eq $NewName){
            "==Computer Renamed==" | Add-LogMessage $logPath
            "Computer New Name: $NewName" | Add-LogMessage $logPath
            Rename-Computer -NewName $config.ComputerRename.NewName -Restart
        }
    }else{
        $Check = $true
        while($Check){
            switch(Read-Host -Prompt "Please enter the new computer name. (Leave blank to skip)"){
                {$_ -eq $ComputerName} {
                    Write-Host "This is already the given name of the device. Continuing with the script."
                    "==Renamed Skipped==" | Add-LogMessage $logPath
                    $Check = $false
                }
                {$_ -ne ''} {
                    Write-Host "Computer renamed: $_"
                    "==Computer Renamed==" | Add-LogMessage $logPath
                    "Computer New Name: $NewName" | Add-LogMessage $logPath
                    $Check = $false
                    Rename-Computer -NewName $_ -Restart -Force
                }
                default {
                    Write-Host 'No name given.'
                    "==Renamed Skipped==" | Add-LogMessage $logPath
                    $Check = $false
                }
            }
        }
    }
}

<# UserSettings #>
$UserSettingsCheck = $logFile | Where-Object{$_ -match "==UserSettings End=="}
if($config.UserSettings -and -not $UserSettingsCheck){
    "==UserSettings Start==" | Add-LogMessage $logPath
    # Recovers the registry changes.
    $Registries = $config.UserSettings.Registry
    # Prepares the environment.
    if($Registries.Path | Where-Object{$_ -match "HKU:\\"}){
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    }
    if($Registries.Path | Where-Object{$_ -match "HKLM:\\Default"}){
        REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
    }
    if($config.UserSettings.RunForExistingUsers){
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
                "$($Registry.DisplayName): Registry value changed" | Add-LogMessage $logPath
                "$($Registry.Path) - $($Registry.Name) - $($Registry.Value)" | Add-LogMessage $logPath
            }else{
                $params["Value"] = $Registry.Value
                $params["PropertyType"] = $Registry.PropertyType
                New-ItemProperty @params -Force
                "$($Registry.DisplayName): Registry value created" | Add-LogMessage $logPath
                "$($Registry.Path) - $($Registry.Name) - $($Registry.Value)" | Add-LogMessage $logPath
            }
        }else{
            New-Item @params -Force
            "$($Registry.DisplayName): Registry path created" | Add-LogMessage $logPath
            $params["Value"] = $Registry.Value
            $params["PropertyType"] = $Registry.PropertyType
            New-ItemProperty @params -Force
            "$($Registry.DisplayName): Registry value created" | Add-LogMessage $logPath
            "$($Registry.Path) - $($Registry.Name) - $($Registry.Value)" | Add-LogMessage $logPath
        }
    }
    "==UserSettings End==" | Add-LogMessage $logPath
}

<# LocalAdminPassword #>
$LocalAdminPasswordCheck = $logFile | Where-Object{$_ -match "==LocalAdminPassword End=="}
if($config.LocalAdminPassword -and -not $LocalAdminPasswordCheck){
    # Generates the new password.
    "==LocalAdminPassword Start==" | Add-LogMessage $logPath
    $Check = $false
    $NewPassword = while(-not $Check){
        $Characters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789'
        $Symbols = '!@#$%&*?'
        $Template = -join (1..10 | ForEach-Object {Get-Random -InputObject $characters.ToCharArray()})
        $Template += -join (1..2 | ForEach-Object {Get-Random -InputObject $Symbols.ToCharArray()})
        if($Template -cmatch "==A-Z==" -and $Template -cmatch "==a-z==" -and $Template -match "\d"){
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
    "Password documentation file created" | Add-LogMessage $logPath
    # Verifies if the source disk is avilable.
    $Origin = ($logFile | Where-Object{$_ -match "SourceLocation="}).Split('=')[1]
    if(Test-Path -Path $Origin){
        # Copies the password file to the source disk.
        Copy-Item -Path $PswFile -Destination $Origin
        "Password file copied to source directory" | Add-LogMessage $logPath
    }else{
        # Source disk cannot be found stores the password
        # documentation file on the desktop.
        Copy-Item -Path $PswFile -Destination "$Env:USERPROFILE\Desktop"
        "Source disk could not be reached." | Add-LogMessage $logPath
        "Password file stored on the user's desktop." | Add-LogMessage $logPath
    }
    # Creates a script to change the current user's password
    # and stores it on the desktop.
    $scriptPath = "$Env:USERPROFILE\Desktop\PswdChange.bat"
    $script = "@echo off
    echo This script will change the curen't user's password.
    echo Make sure to recover the file prior to running this command.
    pause
    NET USER $User $NewPassword" 
    $script | Out-File -FilePath $scriptPath -Encoding utf8 -Force
    "Password change script stored on desktop." | Add-LogMessage $logPath
    "==LocalAdminPassword End==" | Add-LogMessage $logPath
}

<# Cleanup #>
$CleanupCheck = $logFile | Where-Object{$_ -match "==Cleanup End=="}
if($config.Cleanup -and -not $CleanupCheck){
    "==Cleanup Start==" | Add-LogMessage $logPath
    # Copies the password CSV document to the desktop
    # in case some are still present in the prep folder.
    $PasswordCheck = Get-ChildItem -Path "$parentFolder\Password*.csv" -Recurse
    if($PasswordCheck){
        $PasswordCheck | Copy-Item -Destination $Env:USERPROFILE\Desktop
    }
    # Removes existing shortcuts from the desktop.
    if($config.Cleanup.DesktopCleanup){
        Remove-Item -Path "$Env:USERPROFILE\Desktop\*.lnk" -Force
        "Cleaned user desktop" | Add-LogMessage $logPath
    }
    # Removes existing shortcuts from the public desktop.
    if($config.Cleanup.PublicDesktopCleanup){
        Remove-Item -Path "$env:PUBLIC\Desktop\*.lnk" -Force
        "Cleaned Public desktop" | Add-LogMessage $logPath
    }
    if($config.Cleanup.LogBackup){
        # Verifies if the source disk can be contacted.
        $Origin = ($logFile | Where-Object{$_ -match "SourceLocation="}).Split('=')[1]
        $OriginCheck = Test-Path $Origin
        if(-not $OriginCheck){
            "Source location not detected. Waiting for reconnect." | Add-LogMessage $logPath
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
            "Log Folder not found on source disk. New log folder created." | Add-LogMessage $logPath
        }
        Copy-Item -Path $logPath -Destination $LogFolder
        "Log files copied to the source disk: $(Split-Path -Path $logPath -Leaf)" | Add-LogMessage $logPath
    }
    if($config.Cleanup.ScriptFolderRemoval){
        # Prepares the task of removing the prep folder.
        $params = @{
            Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
            Name = "!CleanupFolder"
            PropertyType = "String"
            Value = "CMD /C RD /S /Q C:\Temp\prep"
            Force = $true
        }
        New-ItemProperty @params
        "RunOnce task created." | Add-LogMessage $logPath
    }
    if($config.Cleanup.StartupScriptRemoval){
        # Removes the startup script.
        Remove-Item -Path "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Restart.bat"
        "Restart script removed." | Add-LogMessage $logPath
    }
    if($config.Cleanup.EnableUA){
        # Re-enables UAC.
        $params = @{
            Path = "HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            Name = "EnableLUA"
            Value = 1
            Force = $true
        }
        Set-ItemProperty @params
        "UAC re-enabled" | Add-LogMessage $logPath
    }
    "==Cleanup End==" | Add-LogMessage $logPath
}