# Raspberry as NAS Setup

Configures a raspberry pi as private NAS

Some key concepts for the NAS
* SFTP is the main transport protocol to get data to and from the NAS
* Every user has one writable working directory
* A snapshot of the working directory is taken on a periodic schedule - so history of the working directory is given
* Snapshots are always read-only


Limitations:
* Only one external hard drive is (currently) supported
* No RAID suppoted
* BTRFS is required as file system for the external drive
* Windows user need to install some additional software to access SFTP (see below)


## Script Description

### parameters.sh

In this script, some these important variables are defined:

* DISK_FULL_UUID_PATH
* DISK_FULL_MOUNT_PATH

This is needed for the following scripts.

### 1-host-setup.sh

This is the first script which should be executed, because some basic system setup is done which is not NAS specific but generally good for this Linux System.


### 2-nas-setup.sh

Setup the disk mounts and configures the SFTP working dir for the specified disk.
The disk itself is not touched (e.g. formattted) in any way. To prepare the disk (format and partition), the script `9-format-disk.sh` can be used.

The `parameters.sh` script is mandatory.


### 3-nas-user-setup.sh

This script adds a new user to be used via SFTP. It is a interactive script because the password for the user needs to be entered.
After this script is executed successfully, the SFTP share is usable.

The `parameters.sh` script is mandatory.


### 9-format-disk.sh

Formats and prepares the passed disk to be usable for the NAS

WARNING:

All data on the disk is lost


## Folder Structure

The hard drive for the NAS has the following folder structure:

```
/mnt/[MOUNT_NAME]/sftp/[USER_NAME]/current
/mnt/[MOUNT_NAME]/sftp/[USER_NAME]/snapshots/[SNAPSHOT_DATE]
```


e.g.

```
/mnt/disk1/sftp/alice/current
/mnt/disk1/sftp/alice/snapshots/2024-01-01
/mnt/disk1/sftp/alice/snapshots/2024-01-02
```


## Useful commands:

Check the SMART status of disks

```bash
lsblk # Get a list of disks
sudo smartctl -i /dev/sda
```

BTRFS commands

```bash
sudo btrfs subvolume delete [SNAPSHOT_PATH]
```


## Windows Users

To use the SFTP share on Windows, these to programs need to be installed

```ps1
# https://github.com/winfsp/sshfs-win
winget install -h -e --id "WinFsp.WinFsp" ; winget install -h -e --id "SSHFS-Win.SSHFS-Win"
```


## Troubleshooting

### HD-Idle

Disk is not spinning down after 20 Minutes of inactivity

```bash
sudo systemctl status hd-idle
sudo hdparm -C /dev/sda

# Spin down drive immediately
sudo hd-idle -c ata -t /dev/sda
```

Also modifying the `/etc/default/hd-idle` file and adding this option `-l /var/log/hd-idle.log` can help.

