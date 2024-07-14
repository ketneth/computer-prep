<#
This script has been created for the addition and removal of certain settings.
#>

# Questions
$qEnumerateShortcuts = "n"
$qDeletePersonalShortcuts = "n"
$qDeletePublicShortcuts = "n"
$qShellOptions = "n"
$qLocalAdminPassword = "n"

# Questions regarding Taskbar and start settings
$qRemoveTaskView = "n"
$qRemoveWidgets = "n"
$qRemoveChat = "n"
$qMoveStartLeft = "n"
$qRemoveSearch = "n"
$qStartMorePins = "n"
$qStartMoreRecommendations = "n"
$qRunForExistingUsers = "n"

# Variables
$PublicPath = "$env:PUBLIC\Desktop\"
$PersonalPath = "C:\Users\$env:USERNAME\Desktop\"
$ShortcutPath = "*.lnk"
$TaskbarStartScript = " -noprofile -executionpolicy bypass -file C:\Temp\prep\scripts\007.CustomizeTaskbar.ps1"
$TaskbarStartParameters = ""

# Ask to show all options in the explorer shell
$qShellOptions = (Read-Host "Do you prefer to show all options in the shell menu? y/n (Defaults to no)")
if ($qShellOptions -eq "y")
{        
    $ShellOptionsRegistryPath = New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    $ShellOptionsRegistryKey = New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $ShellOptionsRegistryName = "(Default)"
    Set-ItemProperty $ShellOptionsRegistryKey.PSPath -Name $ShellOptionsRegistryName -Value ""
    Get-Process explorer | Stop-Process    
}
# Ask questions regarding the Start and Taskbar settings
$qRemoveTaskView = (Read-Host "Do you want to remove Task View from the Taskbar? y/n (Defaults to no)")
if ($qRemoveTaskView -eq "y")
{
    $TaskbarStartParameters += " -RemoveTaskView"
}
$qRemoveWidgets = (Read-Host "Do you want to remove Widgets from the Taskbar? y/n (Defaults to no)")
if ($qRemoveWidgets -eq "y")
{
    $TaskbarStartParameters += " -RemoveWidgets"
}
$qRemoveChat = (Read-Host "Do you want to remove Chat from the Taskbar? y/n (Defaults to no)")
if ($qRemoveChat -eq "y")
{
    $TaskbarStartParameters += " -RemoveChat"
}
$qMoveStartLeft = (Read-Host "Do you want to make Start left oriented? y/n (Defaults to no)")
if ($qMoveStartLeft -eq "y")
{
    $TaskbarStartParameters += " -MoveStartLeft"
}
$qRemoveSearch = (Read-Host "Do you want to remove Search from the Taskbar? y/n (Defaults to no)")
if ($qRemoveSearch -eq "y")
{
    $TaskbarStartParameters += " -RemoveSearch"
}
$qStartMorePins = (Read-Host "Do you want to add pins to Start? y/n (Defaults to no)")
if ($qStartMorePins -eq "y")
{
    $TaskbarStartParameters += " -StartMorePins"
}
$qStartMoreRecommendations = (Read-Host "Do you want to show more recommendations in Start? y/n (Defaults to no)")
if ($qStartMoreRecommendations -eq "y")
{
    $TaskbarStartParameters += " -StartMoreRecommendations"
}
$qRunForExistingUsers = (Read-Host "Do you want to modify these settings for all profiles on this computer? y/n (Defaults to no)")
if ($qRunForExistingUsers -eq "y")
{
    $TaskbarStartParameters += " -RunForExistingUsers"
}
if($TaskbarStartParameters.Length -gt 0)
{
    Start-Process pwsh -Verb runAs -ArgumentList "$TaskbarStartScript + $TaskbarStartParameters"
}

# Enumerate the list of shortcuts
Write-Host "`nDo you want to list all " -NoNewline
Write-Host "public" -NoNewline -ForegroundColor Yellow
Write-Host " and " -NoNewline
Write-Host "personal" -NoNewline -ForegroundColor DarkYellow
$qEnumerateShortcuts = (Read-Host " shortcuts on the desktop? y/n (Defaults to no)")
if ($qEnumerateShortcuts -eq "y")
{
    $PublicShortcutsScript = New-Object -ComObject WScript.Shell
    $PublicShortcuts = Get-Childitem -Path $PublicPath -Filter $ShortcutPath -Recurse |
    ForEach-Object{
        $PublicShortcutsScript.CreateShortcut($_.FullName)
        Write-Host $_.FullName -ForegroundColor Yellow
    }
    $PersonalShortcutsScript = New-Object -ComObject WScript.Shell
    $PersonalShortcuts = Get-Childitem -Path $PersonalPath -Filter $ShortcutPath -Recurse |
    ForEach-Object{
        $PersonalShortcutsScript.CreateShortcut($_.FullName)
        Write-Host $_.FullName -ForegroundColor DarkYellow
    }
    # Ask if the personal shortcuts should be deleted
    $qDeletePersonalShortcuts = (Read-Host "Do you want to remove all personal shortcuts on the desktop? y/n (Defaults to no)")
    if ($qDeletePersonalShortcuts -eq "y")
    {
        $PersonalShortcuts |
        ForEach-Object {
            Remove-Item -Path $_.FullName -Force -Verbose
        }
    }
    # Ask if the public shortcuts should be deleted
    $qDeletePublicShortcuts = (Read-Host "Do you want to remove all public shortcuts on the desktop? y/n (Defaults to no)")
    if ($qDeletePublicShortcuts -eq "y")
    {
        $PublicShortcuts |
        ForEach-Object {
            Remove-Item -Path $_.FullName -Force -Verbose
        }
    }
}

# Ask if the device needs a local admin password.
$qLocalAdminPassword = (Read-Host "`nDo you want to continue with setting a local admin password? y/n (Defaults to no)")
if ($qLocalAdminPassword -eq "y")
{
    Start-Process pwsh -Verb runAs -ArgumentList "C:\Temp\prep\scripts\008.LocalAdminPassword.ps1"
}