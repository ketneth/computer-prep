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
set command=wmic bios get serialnumber /format:value
for /f "tokens=2 delims==" %%a in ('%command%') do set serial=%%a
set serial=%serial: =_%
REM Documents the date at which the script is ran.
echo %DATE% >> C:\Temp\prep\%serial%_log.txt
REM Documents the original hostname.
echo DeviceName=%COMPUTERNAME% >> C:\Temp\prep\%serial%_log.txt
REM Documents the original files' location.
echo SourceLocation=%~dp0 >> C:\Temp\prep\%serial%_log.txt

REM Runs the next script.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Temp\prep\scripts\Main.ps1"
