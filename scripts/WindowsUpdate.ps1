#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)][String]$logPath
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

function Set-Environment {
    param(
        [String]$logPath
    )
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if(!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)){
            Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
        }
        if(!(Get-Module -Name PSWindowsUpdate -ListAvailable -ErrorAction SilentlyContinue)){
            Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
        }
        if((Get-ExecutionPolicy) -eq 'Restricted'){
            Set-ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        }
    }
    catch {
        Return $false
    }
    return $true
    <#
        .SYNOPSIS
        Prepares environment for the scripts.

        .DESCRIPTION
        Verifies the requires ExecutionPolicy, PackageProvider and Module are installed.

        .INPUTS
        None. You can't pipe objects to Set-Environment.

        .OUTPUTS
        A boolean, depending if the invironment could be modified and/or meets the requirements.

        .LINK
        Get-PackageProvider

        .LINK
        Install-PackageProvider

        .LINK
        Get-Module

        .LINK
        Install-Module

        .LINK
        Get-ExecutionPolicy

        .LINK
        Set-ExecutionPolicy
    #>
}

function Update-Computer {
    param(
        [Switch]$AutoReboot
    )
    if(Set-Environment -logPath $logPath){
        "==Windows Update Start==" | Add-LogMessage $logPath
        $Continue = $true
        $Tries = 1
        $InstalledUpdates = @()
        while($Continue -and $Tries -lt 4){
            Write-Host 'Checking updates.'
            Get-WindowsUpdate -IgnoreReboot -OutVariable AvailableUpdates | Out-Host
            if(!$AvailableUpdates){
                Write-Host 'No updates found.'
                break
            }
            $UpdateTest = Compare-Object -ReferenceObject $InstalledUpdates -DifferenceObject $AvailableUpdates.Title -IncludeEqual
            if($UpdateTest.SideIndicator -contains '=>'){
                'Installing updates.' | Add-LogMessage $logPath
                Install-WindowsUpdate -AcceptAll -IgnoreReboot -OutVariable InstallResult | Out-File $logPath -Append
                if($InstallResult.RebootRequired -contains 'True'){
                        Restart-Computer -Force
                }
            }else{
                $Continue = $false
            }
            $InstalledUpdates += ($InstallResult | Where-Object{$_.Result -ne 'Failed'}).Title
            if($InstallResult.Result -contains 'Failed'){
                $Tries++
                if($Tries -eq 3){
                    "ERROR`tFailed to install updates 3 times." | Add-LogMessage $logPath
                }
            }
        }
    }else{
        "ERROR`tFailed to configure environment." | Add-LogMessage $logPath
    }
    "==Windows Update End==" | Add-LogMessage $logPath
        <#
        .SYNOPSIS
        Installs Windows updates.

        .DESCRIPTION
        Downloads and installs available Windows updates.

        .PARAMETER logPath
        Path to file to which the status and messages of the function
        will be written.

        .INPUTS
        None. You can't pipe objects to Update-Computer.

        .OUTPUTS
        Host prompts regarding the state of the update installation.
    #>
}

Update-Computer -logPath $logPath

<#
    .SYNOPSIS
    Installs the updates on the host computer.

    .DESCRIPTION
    Prepares the host computer and installs the PSWindowsUpdate module.
    Installs updates and restarts the computer if requested to.

    .PARAMETER logPath
    Path to the file to which the status of the script.

    .INPUTS
    None. You can't pipe objects to WindowsUpdate.ps1.
#>
