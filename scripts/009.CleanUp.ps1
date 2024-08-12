# Clean up
$STName = "Task 9: Clean Up"
$STExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $STName}
if ($STExists)
{
    UnRegister-ScheduledTask -TaskName $STName -Confirm:$false
}

Remove-Item -Path "C:\Temp\prep\" -Recurse -Verbose