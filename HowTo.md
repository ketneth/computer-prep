# HowTo

0. Clone or copy the contents of this repository onto a network share or USB drive.
1. Go over the contents of the [config](/Config.json) file and disable unwanted features.
2. Unbox your device untill you reach the desktop.
    - Create a local user without a password.
3. Connect to the drive from the host.
4. Run [Start.bad](/Start.bat)
    - The script will automatically try to restart itself as administrator.
5. Approve the run as administrator and let the script do its work.
6. Once the script is done, you will have 2 possibilities:
    1. The script managed to find the source disk and copied the important files to it.
    2. The script failed to find the source disk and will be asking you to connect it to finalize.
