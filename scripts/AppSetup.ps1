<#
    Manages the application installation and removal.
    - Installs the applications contained in the C:\Temp\prep\apps folder.
#>

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

$Applications = Get-ChildItem -Path C:\Temp\prep\apps -Include "*.exe","*.msi","*.msix" 
$InstallInstructions = "C:\Temp\prep\apps\Setup.csv"

if($ApplicationInstall){
    # Documents the application install start time.
    "[AppSetup Start]" | Add-LogMessage $LogFile
    
    # Gets the log file contents.
    $Logs = Get-Content -Path $LogFile

    # Recovers application installation commands.
    $Commands = Import-Csv -Path $InstallInstructions

    foreach($Application in $Applications){
        # Verifies there has already been an attempt at installing the application
        # or if the application is already installed.
        if($Logs -like "*Installing*$($Application.Name)*" -or (Test-Path -Path $Application.InstallTest)){
            Continue
        }else{
            # Verifies if the found application has an installation command.
            $InstallCommand = ($Commands | Where-Object($_.application -eq $Application.Name)).Command
            if($InstallCommand){
                "Installing (Automatic) $($Application.Name) $InstallCommand" | Add-LogMessage $LogFile
                Start-Process -FilePath $Application.FullName -ArgumentList $InstallCommand -Verb RunAs -Wait -OutVariable InstallResult
                if($InstallResult){
                    $InstallResult | ForEach-Object("`t$_" | Add-LogMessage $LogFile)
                }
            }else{
                "Installing (Manual) $($Application.Name)" | Add-LogMessage $LogFile
                Start-Process -FilePath $Application.FullName -Verb RunAs -Wait
            }
        }
    }

    # Documents the application install end time.
    "[AppSetup End]" | Add-LogMessage $LogFile
}