#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

disk_path="$1"
disk_label="$2"

if [ -z "$disk_path" ] || [-z "$disk_label" ]; then
    echo "Usage: $0 [DISK_PATH] [NEW_DISK_LABEL]"
    echo "    e.g. $0 /dev/sda disk1"
    exit 1
fi

printf "\n== (re-)partition $disk_path ==\n"
parted "$disk_path" --align opt mklabel gpt 0% 100%
parted "$disk_path" --align opt mkpart primary 0% 100%

mkfs.btrfs -f -L "$disk_label" "${disk_path}1"

hdparm -B
