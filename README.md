# Google Drive Backup
### A docker based utility to backup Google Drive for Google Apps users.

This is a docker image that uses [gam](https://github.com/jay0lee/GAM) and [brive](https://github.com/wk8/Brive) utilities.  Gam is used to download a list of users from your Google Apps domain and brive is used to download items from the user's google drive.  There is some setup required for gam and brive.  You will need to see their individual pages for more details.  This docker image was built for windows native containers.  I would be open to a pull request to duplicate the functionality for Linux containers.

## Initializing the container
The gam and brive tools need to be configured to work with your google apps instance.  There are instructions on their respective pages that we will not cover here.  To begin initilization, however, we need to start the container and initialize the folder structure.

:bell: You'll want to have persistent data volumes for **c:\data**, **c:\gam**, and **c:\config**
*/config
 *Must contain a file called settings.yml that has the brive settings (see brive instructions on github.)
 *Also contains a .p12 file from Google's developer console. (see brive instructions on github.)
*/data
 *Will contain the downloaded user data.
*/gam
 *Contains the gam executable and stores the private gam files for authentication to Google.
 *gam executable is available in the container at /gam if no volume is mounted.

:warning: Typically in a docker image, we could pre-populate a folder like c:\gam with the data needed.  In a linux environment, if you attach a blank bind-mount to this folder, docker will copy the contents into your volume mount.  Due to a bug in windows containers & docker, you cannot start a container unless the target of a bind-mount is completely empty.  Therefore, we had to place the gam tools in a separate folder.
**After you start up the container you will need to copy this tool into place as you'll see below.**

Run the docker image interactively. Use the following examples for reference.

**Docker run examples:**

`docker run -i --name googledrivebackup -v C:\data -v C:\config -v C:\gam wusa\googledrivebackup powershell`

`docker run -i --name googledrivebackup -v C:\GDrive\data:C:\data -v C:\GDrive\gam:C:\gam -v C:\GDrive\config:C:\config wusa/googledrivebackup powershell`


Once the container is started and you're running in the shell, copy the gam and gyb folders into place
```
Copy-Item -Recurse -Force C:\gam-src\* c:\gam\
```

After following the brive setup instructions, copy your `settings.yml`, and `*.p12` to c:\config (your data volume or bind-mount).  Make sure the settings in settings.yml use root_dir of `C:\data\` as well as referencing your other pertinent brive configuration data.


### Configure [gam](https://github.com/jay0lee/GAM) & [brive](https://github.com/wk8/Brive).
Navigate to the web pages for each of these packages.  Follow their instructions for configuration.  You may need to stay in the container's shell to access the commands.

## Post-Initialization: Running the container.
**Docker run examples:**

`docker run -d --name googledrivebackup -v C:\data -v C:\config -v C:\gam wusa/googledrivebackup`


**Environment Variable options:**

`maxParallel` - [int] [`2`] Configure the maximum number of accounts to backup in parrallel.
`brivePreferredFormats` - [string] [`pptx,docx,xlsx,jpg`] Configure the preferred formats for Brive to convert google docs into.  If you don't it will download them in every available format. File extensions must be comma separated.

**Other Notes:**
*Suggest enabling long file name support on the windows host as google doc folder paths can become quite lengthy.

**Known Issues:**
Team drive documents are not backed up, since this process uses the list of users and the documents they own to download files.  Since team drive documents list no owner, it's unlikely they'll be captured.  It's unknown whether the Brive utility could even handle team drive documents.