# HowTo

> :information_source: Script has yet to be tested when ran from a network location.
> Currently, the expected behaviour is to run it from a USB stick.

0. Clone or copy the contents of this repository onto a network share or USB drive.
1. Go over the contents of the [config](/Config.json) file and disable unwanted features.
    - All changes are enabled by default.
    - Add you own registry keys depending on the required changes. (Refer to [README](/README.md#registry) for configuration details.)
2. Unbox your device untill you reach the desktop.
    - Create a local user without a password. (Configuring one at this stage, will require you to re-enter if after each reboot.)
3. Connect to the drive from the host.
4. Run [Start.bad](/Start.bat)
    - The script will automatically try to restart itself as administrator.
5. Approve the run as administrator and let the script do its work.

## Finish

Once the script is done, you will have 2 possibilities:

- The device from which the script was started can be detected and all the remaining changes will have been made.
    1. Nothing needs to be done. The source disk should contain the logs and the password file (if so [configured](/Config.json)).
    2. Remove the USB stick and use the password from the password CSV file to log into the user.
- The device coudln't be detected and the script will have paused the final operations.
  The Script will then also be asking to reconnect the original device.
    1. Reconnect the device.
    2. Wait for the script to finish.
    3. If you enabled `LocalAdminPassword` setting within the [Config File](/Config.json) :
        1. Copy the CSV file from the current user's desktop to the source disk.
        2. Run the `PswdChange.bat` file you'll find on the current user's desktop. This will set the current user's password to the one found within the password CSV-file.
    4. Restart the computer. The script will automatically remove the remaining files at the next logon.
