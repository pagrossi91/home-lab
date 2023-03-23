# My Home Lab For Dummies Setup <!-- omit in toc -->

NOTE: This guide is a work in progress. The documentation is being completely overhauled at the moment, so content may be incomplete, out of date, and/or very disjointed. 

This guide is intended to be an end-to-end guide to set up a home server running various services via Docker. This will aid in replicating the server when I inevitably screw it up somehow and to document what I did and why I did it.

Since it's already set up with Watchtower, Pi-Hole, and a basic Home Assistant setup running, the initial setup is the result of backtracking the steps I needed to take and, as a result, may not be completely comprehensive.

Coming soon: Project Roadmap documented in GitHub's Issues feature.

### Table of Contents <!-- omit in toc -->
- [1. Hardware and OS Setup](#1-hardware-and-os-setup)
  - [1.1. Set up Intel-based laptop](#11-set-up-intel-based-laptop)
    - [1.1.1. Install the Operating System](#111-install-the-operating-system)
  - [1.2. Set up Raspberry Pi 3](#12-set-up-raspberry-pi-3)
    - [1.2.1. Install the Operating System](#121-install-the-operating-system)
      - [1.2.1.1. Method One (Create install drive with Raspberry Pi Imager)](#1211-method-one-create-install-drive-with-raspberry-pi-imager)
      - [1.2.1.2. Method Two (Create install drive with balenaEtcher)](#1212-method-two-create-install-drive-with-balenaetcher)
    - [1.2.2. Configure Internet Access](#122-configure-internet-access)
      - [1.2.2.1. Option One: Ethernet (Recommended)](#1221-option-one-ethernet-recommended)
      - [1.2.2.2. Option Two: Wifi](#1222-option-two-wifi)
    - [1.2.3. Configure Remote Access](#123-configure-remote-access)
    - [1.2.4. Configure Credentials](#124-configure-credentials)
  - [1.3. Install Docker and Docker Compose](#13-install-docker-and-docker-compose)
  - [1.4. Install Git and Set up the Repository](#14-install-git-and-set-up-the-repository)
    - [1.4.1. Installing and Configuring it with GitHub](#141-installing-and-configuring-it-with-github)
    - [1.4.2. Finalize Migrating Project Repository Data](#142-finalize-migrating-project-repository-data)
- [2. Basic Server Access and Maintenance](#2-basic-server-access-and-maintenance)
  - [2.1. Establish Remote Connection with Server](#21-establish-remote-connection-with-server)
  - [2.2. Update OS and Installed Packages](#22-update-os-and-installed-packages)
  - [2.3. Copy Files Between Dev Computer and Server](#23-copy-files-between-dev-computer-and-server)
    - [2.3.1. Copy from dev computer to server](#231-copy-from-dev-computer-to-server)
    - [2.3.2. Copy from server to dev computer](#232-copy-from-server-to-dev-computer)
- [3. Utilization of GitHub](#3-utilization-of-github)
- [4. Development, Testing, and Deployment](#4-development-testing-and-deployment)
  - [4.1. Development and Testing on the _dev_ Branch](#41-development-and-testing-on-the-dev-branch)
  - [4.2. Deployment on the RPi from the _master_ Branch](#42-deployment-on-the-rpi-from-the-master-branch)
- [5. Home Assistant](#5-home-assistant)
  - [5.1. Z-Wave and Zigbee Controller Setup](#51-z-wave-and-zigbee-controller-setup)
    - [5.1.1. Updating Zigbee Firmware](#511-updating-zigbee-firmware)
    - [5.1.2. Updating Z-Wave Firmware](#512-updating-z-wave-firmware)
  - [5.2. Migrating from Z-Wave (depricated) intregation to Z-Wave JS integration](#52-migrating-from-z-wave-depricated-intregation-to-z-wave-js-integration)
  - [Custom Database Usage](#custom-database-usage)
  - [6. MQTT Broker](#6-mqtt-broker)
    - [6.1. Setting up Mosquitto](#61-setting-up-mosquitto)
    - [6.2. Connecting Mosquitto MQTT to Home Assistant](#62-connecting-mosquitto-mqtt-to-home-assistant)
    - [6.3. Adding Amcrest devices to Home Assistant](#63-adding-amcrest-devices-to-home-assistant)
  - [7. Amcrest Local Processing with Frigate](#7-amcrest-local-processing-with-frigate)
    - [7.1. Configuring Frigate](#71-configuring-frigate)
    - [7.2. Setting up Frigate Integration in Home Assistant](#72-setting-up-frigate-integration-in-home-assistant)
    - [7.3. Playing Back Recorded Media](#73-playing-back-recorded-media)
    - [7.4. Home Assistant Notifications for Frigate Events](#74-home-assistant-notifications-for-frigate-events)
- [8. Pi-Hole](#8-pi-hole)
- [9. Portainer](#9-portainer)
- [10. Troubleshooting](#10-troubleshooting)

## 1. Hardware and OS Setup

### Current Home Server Environment <!-- omit in toc -->

- Server Hardware: HP Envy laptop
- Server OS: Ubuntu 22.04 LTS
- Server internet connection: Ethernet
- Development computer: Windows 11 Pro using VS Code

### Nominclature: <!-- omit in toc -->
- Regardless of the machine used to host the Home Server, the device will be referenced herein as "server" with the exception of Sections "[Set up Intel-based laptop](#12-set-up-intel-based-laptop)" and "[Set up Raspberry Pi 3](#13-set-up-raspberry-pi-3)". 
- Variables shown as `<variable_name>` should be taken as needing to be changed to the appropriate variable without the `<>`.
- Terminal can be the command line app from Linux or MacOS, or the Terminal window in an IDE such as VS Code.

### 1.1. Set up Intel-based laptop

If you want to set this up on an old laptop or computer, follow this setup. An HP Envy laptop is the current machine running the Home Server.

#### 1.1.1. Install the Operating System
(In progress) (From memory, may not be comprehensive) 
- Install Ubuntu
- Set up internet
- Set up ssh
- Configure laptop to run when lid is closed
- Proceed to Sections [1.3. Install Docker and Docker Compose](#13-install-docker-and-docker-compose) and [1.4. Install Git and Set up the Repository](#14-install-git-and-set-up-the-repository).

### 1.2. Set up Raspberry Pi 3

If you want to set this up on a Raspberry Pi, follow this setup. This installation process will set up a headless (i.e. without a GUI or peripherals such as monitor and keyboard) Raspberry Pi OS on a Raspberry Pi 3 (RPi3). This method allows for an extremely lightweight operating system on the RPi3.

These steps were accomplished in macOS and thus are macOS specific. Windows or Linux may or may not be similar.

#### 1.2.1. Install the Operating System
This will install Raspberry Pi OS Lite on the drive intended for the RPi3.

##### 1.2.1.1. Method One (Create install drive with Raspberry Pi Imager)
1. Mount the microSD card or whichever drive that will be running on the RPi to the dev computer.
2. Download and install the [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
3. In Operating System, select "Raspberry Pi OS (other)" and select "Raspberry Pi OS Lite (32-bit)"
4. In Storage, select the correct drive*.
5. Click Write.
##### 1.2.1.2. Method Two (Create install drive with balenaEtcher)
1. Mount the microSD card or whichever drive that will be running on the RPi to the dev computer.
2. Download [balenaEtcher](https://www.balena.io/etcher/).
3. Download [Raspberry Pi OS Lite](https://www.raspberrypi.com/software/operating-systems/). 
4. Select the Raspberry Pi OS Lite image.
5. Select the correct drive*.
6. Click Flash.

This will go quickly (approximately 1-2 minutes).

_*Note: You may have to give each of either of these programs permission to write to mounted drives within macOS. Pop-ups may allow you grant permissions or you'll have to do it through the Security & Privacy settings. Ensure "Removable Media" is checked for whichever imager you're using in the "Files and Folders" section of the Privacy tab._

#### 1.2.2. Configure Internet Access
Re-mount the drive in macOS for the following steps:
##### 1.2.2.1. Option One: Ethernet (Recommended)
Connect an ethernet cable from the RPi3 to the modem or router. An ethernet connection is recommended for improved connection reliability and latency.

##### 1.2.2.2. Option Two: Wifi
If you're using an ethernet cable for internet, this step is optional, but it may be a good backup plan for connectivity.

In terminal, create a `wpa_supplicant.conf` file in the boot partition of the RPi3 drive

    nano /Volumes/boot/wpa_supplicant.conf

Then add this to the file in the nano editor that follows, being sure to replace the `<SSID>` and `<password>` with your local network credentials. Change your country, if necessary.

    country=US
    ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
    update_config=1
    
    network={
      ssid=<SSID>
      psk=<password>
    }

#### 1.2.3. Configure Remote Access

With the drive mounted in macOS, enter into Terminal:

    touch /Volumes/boot/ssh

Safely eject the drive from your computer and connect it to your RPi3. Connect RPi3 to ethernet (if applicable) and connect it to power.

Wait a moment for the system to boot. Then in Terminal from macOS, access the RPi3 from a valid ssh command and type `yes` to add the RPi3 as a known host:

    ssh pi@raspberrypi
    ssh pi@raspberrypi.local
    ssh pi@<IP Address>

Set each of these up. We'll need to `exit` the `ssh` connection each time to configure all three commands.

#### 1.2.4. Configure Credentials
We now have a RPi3 with an OS installed, configured to connect to our ethernet and/or wifi, and with the ability to remotely access the device. Let's access it and secure it:

    ssh pi@raspberrypi

Follow the instructions to set a new password. We're already logged in as user `pi` (indicated by the `pi` part of the above command) then enter password `passwd` to set a new password. The default password is `raspberry`.

Update the current installation before proceeding. See the [Update OS and Installed Packages](#update-os-and-installed-packages) section. Once complete, the server is ready to install software and experiment!

### 1.3. Install Docker and Docker Compose
We're going to use Docker and Docker Compose to run our programs (called services in Docker). This keeps the server OS clean and free of clutter, allows us to experiment with configurations in the isolation of containers, and provides us portability when this all goes south again. That is, we can easily set up the exact same instantiation (i.e. configuration) of whatever services are being run by executing a `docker-compose.yml` file.

This is nice and straightforward thanks to a [five-step process posted by Rohan Sawant](https://dev.to/rohansawant/installing-docker-and-docker-compose-on-the-raspberry-pi-in-5-simple-steps-3mgl).

1. Install Docker.

       curl -sSL https://get.docker.com | sh

2. Set permissions to run Docker. Docker's [rootless mode](https://docs.docker.com/go/rootless/) was enticing but we'll be exposing ports. Exposing certain ports is limited in rootless mode so we'll be using enabling [root (daemon) access](https://docs.docker.com/go/daemon-access/) instead. It's tried and true. These two commands add root permissions to `<user>` to run Docker commands, then reboots for this change to take effect.
              
              sudo usermod -aG docker <user>
              sudo reboot
          
3. Test Docker installation

       docker run hello-world

4. Install required dependencies
    
       sudo apt-get install -y libffi-dev libssl-dev

       sudo apt-get install -y python3 python3-pip

       sudo apt-get remove python-configparser

5. Install Docker Compose

       sudo pip3 -v install docker-compose

6. Test installation of Docker Compose

       docker-compose --version

    with output similar to `docker-compose version 1.29.2, build unknown`

The Docker Engine and Docker Compose should now be installed. Proceed to Sections [1.3. Install Docker and Docker Compose](#13-install-docker-and-docker-compose) and [1.4. Install Git and Set up the Repository](#14-install-git-and-set-up-the-repository).

### 1.4. Install Git and Set up the Repository

#### 1.4.1. Installing and Configuring it with GitHub
GitHub is the service used to store the server configurations. 

1. [Install git](https://git-scm.com/downloads). This may not be necessary if Ubuntu was installed. Make sure these commands are executed in a Terminal window connected to the server via SSH or from the server itself.

       sudo apt-get install git

2. [Set a username](https://docs.github.com/en/get-started/getting-started-with-git/setting-your-username-in-git_) so the server associates changes made on this device with that user. This name is independent of your git account.

       git config --global user.name "<First Last>"

    Confirm the username took with the following

       git config --global user.name

    and the output should match `First Last`

3. Next, [associate the GitHub account with the local git installation](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-user-account/managing-email-preferences/setting-your-commit-email-address) so that when changes are committed, git knows where to commit those changes:

       git config --global user.email "<email@example.com>"

    Confirm the username took with the following

       git config --global user.email

    and the output should match `email@example.com`

4. Authenticate the connection to the GitHub account. We'll be [connecting via SSS](https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-ssh-urls), so let's [generate a new SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent). When we create this key, there are two parts: the private key (which is linked with the device) and the public key (which is published to the service, GitHub in this case).

       ssh-keygen -t ed25519 -C "<your_email@example.com>"

    Then, hit Enter when prompted to select a file location to save the key. This selects the default file location. The secure passphrase is next, if desired. If used, this will be presented for you to enter each time you commit and is unique to the SSH key pair.

5. To add the new SSH key to the GitHub account, copy the SSH public key by entering the following command

       cat ~/.ssh/id_ed25519.pub

    and selecting and copying the output. Follow the screenshots in the [GitHub documentation for adding the SSH public key to the account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account). Git is now configured and connected with the GitHub account.

6. Clone the repository into the desired directory. Not specifying the directory in the command will create a new directory in the current directory with the name of the repository. Adding a `.` to the end of the command will create the repository in the current directory, but it must be empty. Check it's empty with `ls -a`. Alternatively, the directory name can be specified at the end of the command.

       gh repo clone git@github.com:<user>/<repo_name>.git ./<custom_name>

    Type `yes` when prompted to continue connecting via the SSH fingerprint. This will finish the link between the SSH key, the GitHub account, and the cloned repo.

7. Check the repository cloned successfully by confirming no errors in the Terminal output and also by navigating to the directory and checking the files are there:

       cd custom_name
       ls

Success! The projects, as uploaded to GitHub, are cloned to the server directory. 

#### 1.4.2. Finalize Migrating Project Repository Data
The secrets and other sensitive information files need to copied over now from the dev computer. I intend to streamline, automate, or negate this process eventually, but for now it's a straight copy command between devices, per the [2.3. Copy Files Between Dev Computer and Server](#23-copy-files-between-dev-computer-and-server) section. The remaining files are:
- `Home-Server/.env`
- `Home-Server/homeassistant/.env`
- `Home-Server/homeassistant/config/secrets.yaml`
- `Home-Server/homeassistant/config/.storage` directory associated with Home Assistant

A file, named scp_scripts.txt is saved locally on the dev computer for easy copy and pasting. This is destined to become a bash script.

## 2. Basic Server Access and Maintenance

### 2.1. Establish Remote Connection with Server

We access the server remotely from the dev computer via ssh. 

1. Either of the following commands will work given they were configured in the [Configure Remote Access](#configure-remote-access) section.

       ssh <user>@<IP Address>

    On the RPi3, the following commands can also be used, where `pi` is the user. 

       ssh pi@raspberrypi
       ssh pi@raspberrypi.local
       ssh pi@<IP Address>

1. Enter the user's password.

### 2.2. Update OS and Installed Packages

To [update the OS and packages installed directly to the OS](https://www.raspberrypi.com/documentation/computers/os.html), execute the following commands. The first command updates the list of software packages and dependencies installed. The second command updates them all to their latest versions.

	sudo apt update
	sudo apt full-upgrade

### 2.3. Copy Files Between Dev Computer and Server

Copying files between devices is simple. From Terminal on the dev computer (i.e. not SSHed into the server) enter the following, where the first location is the directory to copy _from_ and the second location is the directory to copy _to_:

#### 2.3.1. Copy from dev computer to server

	scp /local/directory/ <user>@<IP Address>:~/remote/directory/

#### 2.3.2. Copy from server to dev computer

	scp <user>@<IP Address>:~/remote/directory/ /local/directory/ 

## 3. Utilization of GitHub

GitHub is used to store the configuration files for all the services. This allows the expeditious deployment of identical services to a new Raspberry Pi or hardware environment.

Eventually, hopefully the database logs will also be transferable but right now they save data indiscriminately and are too large, so they are omitted. With the databases omitted, new deployments would behave as brand-new systems with zero history. On the current server, the databases are persistent, so unless user error deletes the databases or the storage is corrupted, there is at least some historical database.

When .gitignore is updated and we wish to [stop tracking files and remove them from the repository](https://stackoverflow.com/a/13541721), execute the following command:

    git rm --cached `git ls-files -i -c --exclude-from=.gitignore`

## 4. Development, Testing, and Deployment

The system is deployed on the server, using the _master_ branch. 

To run the services on the server, from the repository folder `~/Home-Server`, run 

    cd ~/Home-Server
    docker-compose up -d

For Home Assistant and its supporting services, navigate to the `homeassistant` directory and repeat the command

    cd ~/Home-Server/homeassistant
    docker-compose up -d

The first time will take a few minutes while the images download.

### 4.1. Development and Testing on the _dev_ Branch

This workflow is TBD. I may just have to continue developing on the production server.

### 4.2. Deployment on the RPi from the _master_ Branch

TBD. Merge changes from _dev_ to _master_ branch.


## 10. Troubleshooting

- If a Docker image is started without first creating the mapped directories and files, it'll need to be stopped and the directories removed. By default, if Docker creates mapped volumes, it creates them as directories. Remove the directories on the server then recreate them before rebuilding the image. 
  1. Method One: This is easiest in the Explorer tree in VS Code.
  2. Method Two: Command line example

    sudo rm -r ~/Home-Server/pi-hole/var-log/pihole.log
    sudo touch ~/Home-Server/pi-hole/var-log/pihole.log

    sudo rm -r ~/.docker/config.json
    echo {} > ~/.docker/config

- [How to access files from RPi microSD card via macOS](https://www.jeffgeerling.com/blog/2017/mount-raspberry-pi-sd-card-on-mac-read-only-osxfuse-and-ext4fuse)

------------------------

Ubuntu Server LTS https://ubuntu.com/tutorials/install-ubuntu-server

Set device's IP to static in DHCP server

Setup up partitions https://systemzone.net/ubuntu-server-20-04-installation-with-lvm/
 - 2G ext4 boot partition (also creates 1.049G /boot/efi)
 - 2G swap partition
 - skip /root, /home/, and /var. 
 - Set blank, unformatted for remaining disk space and let Ubuntu configure it automatically
 - Create volume group, select full volumes and unused partition from boot drive
 - Create logical volume on lvm
	- 4G, lv-root, format xfs, mount /
Subnet 192.168.1.0/24
Static IP 192.168.1.100
Gateway 192.168.1.254


UPDATED
 - Set disk as boot device
 - Set remaining space on that drive as blank, unformatted
 - Create volume group, select full volumes and unused partition from boot drive

Continue installation per prompts. When reboot completes, you can continue setup logged in directly to the server, or log in remotely via ssh. You cannot be logged in to the server directly and log in with the same account via SSH.
If you used lvm, verify the drive is showing as the correct size with df -H /boot

Update to latest
	sudo do-release-upgrade 
	sudo apt update
	sudo apt upgrade
	reboot

Set static IP in pihole
Add forwarded ports for new static IP in firewall (router)

Copy files from current/backup location to new server with 

    rsync -r --progress -e ssh  ~/Home-Server/ paul@192.168.1.100:/home/paul/home-server

If using a new static IP, update SERVER_IP varibles in .env, secrets.yml, and frigate/config.yml

Install docker with the latest instructions from https://docs.docker.com/engine/install/ubuntu/

    sudo apt-get update
    sudo apt-get install -y docker.io

Skip hello-world test until running as non-root user

Manage docker as non-root user https://docs.docker.com/engine/install/linux-postinstall/
    
    sudo groupadd docker # This should already exist from the docker installation
    sudo usermod -aG docker $USER
    newgrp docker
    docker run hello-world

Install Docker Compose dependencies
	sudo apt-get install -y libffi-dev libssl-dev
	sudo apt-get install -y python3 python3-pip
	sudo apt-get remove python-configparser

Install Docker Compose
	sudo pip3 -v install docker-compose

Test installation of Docker Compose
	docker-compose --version

Git install is correct
Detail where configurations are backed up. Git only provides capability to build from scratch

Using ftp server to transfer files from Apple Time Capsule (via Windows) to Ubuntu 
- https://www.addictivetips.com/ubuntu-linux-tips/host-an-ftp-server-on-linux/
- https://www.addictivetips.com/ubuntu-linux-tips/connect-to-ubuntu-from-windows/