# RaspberryPI as NAS

![raspberry pi nas](resources/overview.png "Raspberry PI NAS")

This repos setup a Raspberry Pi as private simple NAS.

Some key concepts for the NAS
* SAMBA and SFTP are the main transport protocol to get data to and from the NAS
* Every user has one writable working directory
* A snapshot of the working directory is taken on a periodic schedule - so history of the working directory is given
* Snapshots are always read-only


Limitations:
* OS Setup of the Raspberry Pi is out of scope of this script
* (vanilla) OS must be installed
* Only one external hard drive is (currently) supported
* No RAID suppoted
* BTRFS is required as file system for the external drive


> :warning: **Still under active development with many breaking changes**

# Setup

To setup the NAS, make sure you have the external disk connected which should be used as NAS disk.

1. ```bash
   sudo apt update && sudo apt install -y git
   sudo mkdir -p /opt/
   cd /opt/
   sudo git clone https://github.com/guenhter/raspberry-nas.git
   cd /opt/raspberry-nas
   sudo cp parameters.sample.sh parameters.sh
   ```
1. (Run the destructive script `9-format-disk.sh` if the hard drive is not yet formatted as BTRFS)
1. Define the parameters in `parameters.sh`
1. Run `1-host-setup.sh`
1. Run `2-nas-setup.sh`
1. Run `3-nas-user-setup.sh` for each user to be added as a NAS User

Your Raspberry Pi is now a simple slim NAS ♥♥♥


## Script Description

### parameters.sh

In this script, define these variables:

* DISK_FULL_UUID_PATH
* DISK_FULL_MOUNT_PATH

e.g.

```
DISK_FULL_UUID_PATH="/dev/disk/by-uuid/3980ec2e-6fe3-4c63-8754-18c8ca394446"
DISK_FULL_MOUNT_PATH="/mnt/backup"
```

The following command is useful to find the right disk:
```bash
# Get a list of disks
lsblk

# See all disk UUID's and the link destination
ls -l /dev/disk/by-uuid
```

This is needed for the following scripts.

### 1-host-setup.sh

The first script to be executed. Some basic system setup is done which is not NAS specific but generally good for this Linux System.


### 2-nas-setup.sh

Setup the disk mounts and configures the SAMBA and SFTP working dir for the specified disk.
The disk itself is not touched (e.g. formattted) in any way. To prepare the disk (format and partition), the script `9-format-disk.sh` can be used.

The `parameters.sh` script is mandatory.


### 3-nas-user-setup.sh

This script adds a new user to be used via SAMBA/SFTP. It is a interactive script because the password for the user needs to be entered.
After this script is executed successfully, the SAMBA/SFTP share is usable.

The `parameters.sh` script is mandatory.


### 9-format-disk.sh

Formats and prepares the passed disk to be usable for the NAS

WARNING: ALL DATA ON THE EXTERNAL HARD DRIVE WILL BE LOST WHEN RUNNING THIS SCRIPT



## External Drive Folder Structure

The hard drive for the NAS has the following folder structure:

```
/mnt/[MOUNT_NAME]/[USER_NAME]/current
/mnt/[MOUNT_NAME]/[USER_NAME]/snapshots/[SNAPSHOT_DATE]
```


e.g.

```
/mnt/disk1/alice/current
/mnt/disk1/alice/snapshots/2024-01-01
/mnt/disk1/alice/snapshots/2024-01-02
```


## Useful commands:

Check the SMART status of disks

```bash
lsblk # Get a list of disks
sudo smartctl -i /dev/sda
```

BTRFS commands

```bash
# Delete a subvolume
sudo btrfs subvolume delete [SNAPSHOT_PATH]

# Check if a snapshot is read-only
btrfs property get /path/to/snapshot ro

# Sets snapshot to read-only
sudo btrfs property set /path/to/snapshot ro true
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



## Contribution

Contribution are always welcome in any form.

You acknowledge and agree that the owner reserve the right to change the license of the Work, including but not limited to all Contributions previously submitted by You, at any time without the need for approval from You or any other contributor.

## License

This project is licensed under the [MIT license].

[MIT license]: https://github.com/guenhter/raspberry-nas/blob/main/LICENSE
