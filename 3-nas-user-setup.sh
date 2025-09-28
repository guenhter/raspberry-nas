#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

SCRIPT_DIR=$(dirname -- "$( readlink -f -- "$0"; )")

user_name="$1"

if [ -z "$user_name" ]; then
    echo "Usage: [USER_NAME]"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/parameters.sh" ]; then
    printf "Canont load parameters from ./parameters.sh\n"
    exit 1
fi

printf "\n== Loading parameters ==\n"
source "$SCRIPT_DIR/parameters.sh"

if [ -z "$DISK_FULL_MOUNT_PATH" ]; then
    printf "Variable DISK_FULL_MOUNT_PATH is not set in the parameters file\n"
    exit 1
fi


# https://reintech.io/blog/setting-up-sftp-secure-file-transfers-debian-12

getent group backupusers || groupadd backupusers

adduser --no-create-home --disabled-login --ingroup backupusers --shell /bin/false --gecos "" "$user_name"
passwd "$user_name"

backup_user_root="$DISK_FULL_MOUNT_PATH/$user_name"
mkdir -p "$backup_user_root"
btrfs subvolume create "$backup_user_root/latest"
btrfs subvolume create "$backup_user_root/snapshots"
chown -R "$user_name":backupusers "$backup_user_root/latest" # This is the only dir, where the user can write to
chown -R "$user_name":backupusers "$backup_user_root/snapshots"

# Configure Samba for this user
printf "\n== Configuring Samba for user: $user_name ==\n"

# Add user to Samba
smbpasswd -a "$user_name"

# Create individual Samba share configuration file for this user
cat > "/etc/samba/conf.d/$user_name-backup.conf" <<EOF
[$user_name-backup]
   comment = Backup share for $user_name
   path = $backup_user_root/latest
   valid users = $user_name
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0664
   directory mask = 0775
   force user = $user_name
   force group = backupusers

[$user_name-backup-history]
   comment = Backup History share for $user_name
   path = $backup_user_root/snapshots
   valid users = $user_name
   read only = yes
   browsable = yes
   writable = no
   guest ok = no
   create mask = 0664
   directory mask = 0775
   force user = $user_name
   force group = backupusers
EOF

# Add include directive to main smb.conf if not already present
include_line="include = /etc/samba/conf.d/$user_name-backup.conf"
if ! grep -q "^include = /etc/samba/conf.d/$user_name-backup.conf" /etc/samba/smb.conf; then
    echo "$include_line" >> /etc/samba/smb.conf
fi

# Restart Samba to apply changes
systemctl reload smbd
