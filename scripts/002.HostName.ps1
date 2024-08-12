# Questions
$qHostname = "n"
$qBloatWare = "n"
$qBloatWareProceed = "n"

# Ask and confirm the hostname change 
$qHostname = (Read-Host "Do you want the hostname to be changed? y/n (Defaults to no)")
if ($qHostname -eq "y") {

    # Ask for the hostname
    $Hostname = (Read-Host "What needs to be the hostname of this device? The current name is $Env:ComputerName.")
    while ($Hostname -eq $Env:ComputerName)
    {
        $Hostname = (Read-Host "The hostname needs to be different from the old name.")
    }

    # Ask for BloatWareRemoval Task Creation
    $qBloatWare = (Read-Host "Do you want to create a scheduled task for BloatWare Removal? y/n (Defaults to no)")
    if ($qBloatWare -eq "y") {
        $STName = "Task 3 Remove Bloatware"
        # create a scheduled task with powershell for the next step
        if (Get-ScheduledTask -TaskName $STName -ErrorAction Ignore) {
            Write-Host "$STName exists."
            $Task = Get-ScheduledTask | Where-Object { $_.TaskName -eq $STName } | Select-Object -First 1
            $Task | Unregister-ScheduledTask -Confirm:$false
            Write-Host "$STName was removed" -ForegroundColor Yellow
        }
        $STAction = New-ScheduledTaskAction -Execute '"C:\Program Files\PowerShell\7\pwsh.exe"' -Argument '-Interactive -NoProfile -ExecutionPolicy Bypass -File "C:\Temp\prep\scripts\003.BloatWareRemover.ps1" -Verb RunAs -WorkingDirectory "C:\Temp\prep\scripts\"'
        $STTrigger = New-ScheduledTaskTrigger -AtLogon
        $STSettings = New-ScheduledTaskSettingsSet -Priority 4 -Compatibility Win7 -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $STName -Action $STAction -Trigger $STTrigger -Settings $STSettings -RunLevel Highest
    }
    Write-Host "$Hostname will become the new hostname and a reboot will take place."
    Start-Sleep -Seconds 5
    Rename-Computer -NewName $Hostname -Force -Restart
} else {
    
    # Ask for BloatWareRemoval Task Creation
    $qBloatWareProceed = (Read-Host "Do you want to start BloatWare Removal? y/n (Defaults to no)")
    if ($qBloatWareProceed -eq "y") {
        Start-Process pwsh -Verb runAs -ArgumentList "C:\Temp\prep\scripts\003.BloatWareRemover.ps1"
    }
}
