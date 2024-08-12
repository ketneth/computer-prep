# Install PowerShell 7

#Questions
$qInstallPowershell = "n"

# Variables
$AppsPath = "C:\Temp\prep\apps\"
$MSIPath = "C:\Windows\System32\msiexec.exe"

# Functions
function CheckAppInstallation {
    param (
        $InstalledApp
    )
    $MyApp = Get-WmiObject -Class Win32_Product | sort-object Name | select-object Name | where-object { $_.Name -match $InstalledApp}

    if ($MyApp -match $InstalledApp) {
        Write-Host "$InstalledApp installation previously completed."
        Start-Sleep -Seconds 1.5
        return $true
    } else {
        return $false
    }
}

$qInstallPowershell = (Read-Host "Do you want to install PowerShell 7? y/n (Defaults to no)")
if ($qInstallPowershell -eq "y")
{
    # Install PowerSHell 7
    if (-Not (CheckAppInstallation("PowerShell 7"))) {
        try {
            $App = Get-ChildItem $AppsPath | Where-Object -Property BaseName -like "PowerShell*"
            $FullPath = $AppsPath + $App.Name
            Start-Process $MSIPath -ArgumentList "/package $FullPath /quiet REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait
            Write-Host "PowerShell installation completed."
            Start-Sleep -Seconds 1.5
        } catch{
            Write-Host "PowerShell installation returned the following error $_"
            Start-Sleep -Seconds 1.5
            # If you want to pass the error upwards as a system error and abort your powershell script or function
            Throw "Aborted PowerShell installation returned $_"
        }
    } else {
        Write-Host "PowerShell installation previously completed."
        Start-Sleep -Seconds 1.5
    }
}

# Start the next Script
Start-Process pwsh -Verb runAs -ArgumentList "C:\Temp\prep\scripts\002.HostName.ps1"