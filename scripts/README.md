# Scripts

Scripts used for configuring the computer.

## AppSetup.ps1

> [Script](/scripts/AppSetup.ps1)

1. Will recover the contents of the [app](/apps/)-folder.
2. Recovers the contents of the [Setup.csv](/apps/Setup.csv) file.
3. If present, it will run the `.msi`, `.msix` and `.exe` files with the given installation command.

## BloatwareRemover.ps1

> :warning: Will abort if not run on a HP computer.
> [Script](/scripts/BloatWareRemover.ps1)

Removes all applications corresponding to the manufacturer. (Exceptions are configured to prevent drivers removal.)

## Main.ps1

> [Script](/scripts/Main.ps1)

Core script.
Reads the contents of the [Config.json](/Config.json)-file.
Depending on its settings, will run the [WindowsUpdate](#windowsupdateps1)-, [BloatwareRemover](#bloatwareremoverps1) and [AppSetup](#appsetupps1)-script.

This script will also be responsible for:

- Renaming the device.
- Changing the local administrator password.
- Cleaning up after the scripts are done.

## WindowsUpdate.ps1

> [Script](/scripts/WindowsUpdate.ps1)

Will install all pending Windows updates and will also restart the host if required.
After reboot, it will automatically start searching for updates again.
