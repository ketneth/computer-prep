<#
This script has been created as to simplify the installation of common apps for users and engineers.
#>

# Questions
$qDefaultApps = "n"
$Updates = "n"

# Variables
$AppsPath = "C:\Temp\prep\apps\"
$ContinuumPath = "C:\Temp\prep\apps\continuum\"

# Functions
function Get-InstalledApps {
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [string]$NameRegex = ''
    )
    $AppsList = " "
    foreach ($comp in $ComputerName) {
        $keys = '','\Wow6432Node'
        foreach ($key in $keys) {
            try {
                $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $comp)
                $apps = $reg.OpenSubKey("SOFTWARE$key\Microsoft\Windows\CurrentVersion\Uninstall").GetSubKeyNames()
            } catch {
                continue
            }

            foreach ($app in $apps) {
                $program = $reg.OpenSubKey("SOFTWARE$key\Microsoft\Windows\CurrentVersion\Uninstall\$app")
                $name = $program.GetValue('DisplayName')
                $AppsList += $name
                if ($name -and $name -match $NameRegex) {
                    [pscustomobject]@{
                        DisplayName = $name
                    }
                }
            }
        }
    }
    return $AppsList
}

function CheckAppInstallation {
    param (
        $InstalledApp
    )
    $AppsList = Get-InstalledApps -ComputerName $env:COMPUTERNAME
    if ($AppsList -Like "*$InstalledApp*"){
        Write-Host "$InstalledApp installation previously completed."
        Start-Sleep -Seconds 1.5
        return $true
    }
    else {
        Write-Host "$InstalledApp not yet installed."
        Start-Sleep -Seconds 1.5
        return $false
    }
}

# Install the default apps every PC needs.
$qDefaultApps = (Read-Host "Do you want to install the Default apps? y/n (Defaults to no)")
if ($qDefaultApps -eq "y")
{
    # Install Continuum Agent
    if (-Not (CheckAppInstallation("ITSupport247"))) {
        $directoryInfo = Get-ChildItem $ContinuumPath | Measure-Object
        if ($directoryInfo.count -gt 0) {
            try{
                $App = Get-ChildItem $ContinuumPath | Where-Object -Property Extension -like "*msi"
                $FullPath = $AppsPath + $App.Name
                Start-Process -FilePath $FullPath -Wait -ArgumentList " /qn"
                Write-host -ForegroundColor green "Continuum RMM Agent installed."
                Start-Sleep -Seconds 1.5
            } catch {
                Write-Host -ForegroundColor red "Installation of Continuum RMM Agent failed."
            }
        } else {
            Write-Host -ForegroundColor red "Installation MSI of Continuum RMM Agent not found."
        }
    }

    # Install Adobe Reader DC
    if (-Not (CheckAppInstallation("Adobe Acrobat"))) {
        try{
            $App = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "AcroRdr*"
            $FullPath = $AppsPath + $App.Name
            Start-Process -FilePath $FullPath -Wait -ArgumentList " /S /product=reader"
            Write-host -ForegroundColor green "Adobe Reader installed"
            Start-Sleep -Seconds 1.5
        } catch {
            Write-Host -ForegroundColor red "Installation of Adobe Reader failed."
        }
    }

    # Install Google Chrome
    if (-Not (CheckAppInstallation("Chrome"))) {
        try{
            $App = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "Chrome*"
            $FullPath = $AppsPath + $App.Name
            Start-Process -FilePath $FullPath -Wait -ArgumentList "/silent /install"
            Write-host -ForegroundColor green "Google Chrome installed"
            Start-Sleep -Seconds 1.5
        } catch {
            Write-Host -ForegroundColor red "Installation of Google Chrome failed."
        }
    }

    # Install FortiClient VPN
    if (-Not (CheckAppInstallation("FortiClient VPN"))) {
        try{
            $App = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "FortiClient*"
            $FullPath = $AppsPath + $App.Name
            Start-Process -FilePath $FullPath -Wait -ArgumentList "/passive"
            Write-host -ForegroundColor green "FortiClient VPN installed"
            Start-Sleep -Seconds 1.5
        } catch {
            Write-Host -ForegroundColor red "Installation of FortiClient VPN failed."
        }
    }

    # Install JRE.
    if (-Not (CheckAppInstallation("Java"))) {
        try{
            $App = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "jre*"
            $FullPath = $AppsPath + $App.Name
            Start-Process -FilePath $FullPath -Wait -ArgumentList "/s"
            Write-host -ForegroundColor green "Java Runtime Environment installed."
            Start-Sleep -Seconds 1.5
        } catch {
            Write-Host -ForegroundColor red "Installation of Java Runtime Environment failed."
        }
    }

    # Install Teams machine wide
    if (-Not (CheckAppInstallation("Microsoft Teams"))) {
        try{
            $BootStrapper = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "teamsboot*"
            $FullPathBS = $AppsPath + $BootStrapper.Name
            $MSTeams = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "MSTeams*"
            $FullPathMST = $AppsPath + $MSTeams.Name
            Start-Process -Wait -FilePath $FullPathBS -ArgumentList "-p -o  $FullPathMST"
            Write-host -ForegroundColor green "Teams system-wide installed."
            Start-Sleep -Seconds 1.5
        } catch {
            Write-Host -ForegroundColor red "Installation of Teams failed."
        }
    }
}


# Ask if the updates can be done next.
$Updates = (Read-Host "Do you want continue with updates? y/n (Defaults to no)")
if ($Updates -eq "y")
{
    Start-Process pwsh -Verb runAs -ArgumentList "C:\Temp\prep\scripts\005.WindowsUpdate.ps1"
}