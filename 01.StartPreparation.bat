@echo off

REM Verifies if the script is running as admin.
net session >nul 2>&1
if %errorLevel% == 0 (
    goto Continue
) else (
    REM Restarts the script as admin.
    powershell -command "Start-Process %~dpnx0 -Verb runas"
)

:Continue
REM Checks if the "C:\Temp\prep" folder exists.
IF NOT EXIST C:\Temp\prep MKDIR C:\Temp\prep

REM Copies the contents of the current disk to the destination folder.
pushd %~dp0
XCOPY .\* C:\Temp\prep /S /Y

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Temp\prep\scripts\001.PowerShell7.ps1"
