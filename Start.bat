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

REM Creates a log file named after the serial number of the host computer.
FOR /F "skip=1" %%G IN ('"wmic bios get serialnumber"') DO (ECHO %DATE%>C:\Temp\prep\%%G_log.txt)
echo %~dp0 >> C:\Temp\prep\*_log.txt

REM Runs the next script.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Temp\prep\scripts\001.PowerShell7.ps1"
