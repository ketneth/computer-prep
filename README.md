# computer-prep

The contents of this repository is for setting up newly unboxed devices.

For instructions regarding the exection, refer to the [HowTo](/HowTo.md) file.

## Scripts

Folder contains the scripts used for configuring the device.

## Root Files

### Start.bat

1. Checks the script is running as admin and restarts as admin if that is not the case.
2. Disables UAC for future runs
3. Creates the `C:\Temp\prep` directory if it doesn't exist.
4. Copies the contents of the current directory of the script as well as all subfolders to the `C:\Temp\prep` folder.
5. Creates a logs file named after the serialnumber of the host device.
6. Documents the current hostname and starting directory.
7. Runs the [Main.ps1](/scripts/Main.ps1) script.

### CopyExclusions.txt

File containing the exclusions for the file copy:

- GIT files:
  - .gitignore
  - README.md
- Log folder
- Start.bat script

### Config.json

Contains the parameter for the main scripts.

#### WindowsUpdate

Defines if the [WindowsUpdate.ps1](/scripts/WindowsUpdate.ps1) is run.

#### BloatwareRemoval

Defines if the [BloatwareRemoval.ps1](/scripts/BloatWareRemover.ps1) is run.

#### ComputerRename

Defines if the computer is renamed.
> Not giving filing in the `NewName` value will cause the script to request one when arriving at the renaming step.

#### UserSettings
  
##### DesktopCleaner

Will remove the existing links from the current user's desktop.

##### PublicDesktopCleanup

Will remove existing links from the public desktop.

##### Registry

**DisplayName**: Name that will be displayed when the registry key is added/modified.

**Description**: Description of the change that the registry change will cause.

**Enabled**: Putting this on `false` will cause the parent registry change to be skipped.

**Path**: Path to the registry change.

**Name**: Name of the property that needs to be changed.

**Value**: Value of the property.

**PropertyType**: Type of value. (Ex: DWORD, String, REG_SZ, ...)

## Apps

All `.msi`, `.msix` and `.exe` will be copied onto the host and first be attemted to run using the commands supplied the [Setup.csv](/apps/Setup.csv)-file.

if none are found, the installation file will be run as is and the user will be expected to complete the installation.

### Setup.csv

Contains the installation instructions and follows the following structure:

| Application                          | Command                                   | InstallTest                                           |
|--------------------------------------|-------------------------------------------|-------------------------------------------------------|
| (Full name of the installation file) | (Arguments required for the installation) | (Test to confirm the application is installed)        |
| FortiClientVPN.exe                   | -passive                                  | C:\Program Files\Fortinet\FortiClient\FortiClient.exe |
| Setup64.msi                          | /qn                                       | C:\Program Files\Program\Run.exe                      |

## Logs

This is the folder to which the post-installation-log-files will be copied to.
