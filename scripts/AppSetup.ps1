<#
    Manages the application installation and removal.
    - Installs the applications contained in the C:\Temp\prep\apps folder.
#>

param(
    [Parameter(Mandatory)][String]$LogFile
)

$Applications = Get-ChildItem -Path C:\Temp\prep\apps -Include "*.exe","*.msi","*.msix" 
$InstallInstructions = "C:\Temp\prep\apps\Setup.csv"

if($ApplicationInstall){
    # Documents the application install start time.
    $Date = Get-Date -Format HH:MM:ss
    "$Date`t[AppSetup Start]" | Out-File $LogFile -Append
    
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
            $Date = Get-Date -Format HH:MM:ss
            # Verifies if the found application has an installation command.
            $InstallCommand = ($Commands | Where-Object($_.application -eq $Application.Name)).Command
            if($InstallCommand){
                "$Date`tInstalling (Automatic) $($Application.Name) $InstallCommand" | Out-File -FilePath $LogFile -Append
                Start-Process -FilePath $Application.FullName -ArgumentList $InstallCommand -Verb RunAs -Wait -OutVariable InstallResult
                if($InstallResult){
                    $InstallResult | ForEach-Object("`t$_" | Out-File -FilePath $LogFile -Append)
                }
            }else{
                "$Date`tInstalling (Manual) $($Application.Name)"
                Start-Process -FilePath $Application.FullName -Verb RunAs -Wait
            }
        }
    }

    # Documents the application install end time.
    $Date = Get-Date -Format HH:MM:ss
    "$Date`t[AppSetup End]" | Out-File $LogFile -Append
}