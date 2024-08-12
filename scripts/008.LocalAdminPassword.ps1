<#
This script has been created for Local Admin Password change and instructing the setup of the VPN.
#>

# Questions
$qChangePassword = "n"
$qDomainJoinPC = "n"
$qCleanUp ="n"
$qCleanUp02 ="n"

$qChangePassword = Read-Host "Do you want to change the Local Admin Password that you are using now? y/n (Defaults to no)"
if ($qChangePassword -eq "y")
{
    $Password = (Read-Host "Enter the new password" -AsSecureString)
    $UserAccount = Get-LocalUser -Name $Env:UserName    
    $UserAccount | Set-LocalUser -Password $Password
}

Write-Host "Please set up the VPN connection to the customer. This is a manual step in the GUI."

Write-Host "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Ask if the device needs be domain joined.
$qDomainJoinPC = (Read-Host "Do you want to join this PC to the VPN-connected domain of the customer? y/n (Defaults to no)")
$qCleanUp = (Read-Host "Do you want to clean up the C:\Temp\prep\ folder after the domain join? y/n (Defaults to no)")
if ($qCleanUp -eq "y")
{
    $STName = "Task 9: Clean Up"
    # create a scheduled task with powershell for the next step
    if (Get-ScheduledTask -TaskName $STName -ErrorAction Ignore) {
        Write-Host "$STName exists."
        $Task = Get-ScheduledTask | Where-Object { $_.TaskName -eq $STName } | Select-Object -First 1
        $Task | Unregister-ScheduledTask -Confirm:$false
        Write-Host "$STName was removed" -ForegroundColor Yellow
    }
    $STAction = New-ScheduledTaskAction -Execute '"C:\Program Files\PowerShell\7\pwsh.exe"' -Argument '-Interactive -NoProfile -ExecutionPolicy Bypass -File "C:\Temp\prep\scripts\009.CleanUp.ps1" -Verb RunAs -WorkingDirectory "C:\Temp\prep\scripts\"'
    $STTrigger = New-ScheduledTaskTrigger -AtLogon
    $STSettings = New-ScheduledTaskSettingsSet -Priority 4 -Compatibility Win7 -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
    Register-ScheduledTask -TaskName $STName -Action $STAction -Trigger $STTrigger -Settings $STSettings -RunLevel Highest
}
if ($qDomainJoinPC -eq "y")
{
    $DomainName = Read-Host "What is the domain name?"
    Add-Computer -DomainName $DomainName -restart
} else 
{
    $qCleanUp02 = (Read-Host "Do you want to clean up the C:\Temp\prep\ folder now? y/n (Defaults to no)")
    if ($qCleanUp02 -eq "y")
    {
        Remove-Item -Path "C:\Temp\prep\" -Recurse -Verbose
    }
}