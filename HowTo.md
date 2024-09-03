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
6. Once the script is done, you will have 2 possibilities:
    1. The script managed to find the source disk and copied the important files to it.
    2. The script failed to find the source disk and will be asking you to connect it to finalize.
