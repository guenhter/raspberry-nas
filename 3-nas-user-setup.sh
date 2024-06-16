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

getent group sftpusers || groupadd sftpusers
adduser --no-create-home --disabled-login --ingroup sftpusers --shell /bin/false --gecos "" "$user_name"
passwd "$user_name"

sftp_user_root="$DISK_FULL_MOUNT_PATH/sftp/$user_name"
mkdir -p "$sftp_user_root"
chown root:root "$sftp_user_root"
btrfs subvolume create "$sftp_user_root/latest"
btrfs subvolume create "$sftp_user_root/snapshots"
chown -R "$user_name":sftpusers "$sftp_user_root/latest" # This is the only dir, where the user can write to


# https://github.com/winfsp/sshfs-win
# winget install -h -e --id "WinFsp.WinFsp" ; winget install -h -e --id "SSHFS-Win.SSHFS-Win"
