# computer-prep

The contents of this repository is for setting up new devices.

## Scripts

### 01.StartPreperation.bat

1. Checks the script is running as admin and restarts as admin if that is not the case.
2. Creates the `C:\Temp\prep` directory if it doesn't exist.
3. Copies the contents of the current directory of the script as well as all subfolders to the `C:\Temp\prep` folder.
4. Creates a logs file named after the serialnumber of the host device.
5. Runs the [001.PowerShell7.ps1](/scripts/001.PowerShell7.ps1) script.
