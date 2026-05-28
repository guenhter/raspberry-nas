#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# shellcheck disable=SC1091
source "$SCRIPT_DIR/.parameters.sh"

# Remove trailing slashes
DISK_FULL_MOUNT_PATH="${DISK_FULL_MOUNT_PATH%/}"

for user_dir in "$DISK_FULL_MOUNT_PATH"/*/; do
    # Remove trailing slashes
    user_dir="${user_dir%/}"

    latest_dir="$user_dir/latest"
    snapshots_dir="$user_dir/snapshots"

    if [ ! -d "$latest_dir" ] || [ ! -d "$snapshots_dir" ]; then
        echo "Skipping backup because not all folders exists for $user_dir"
    else
        date=$(date '+%Y-%m-%d')
        new_snapshot_dir="$snapshots_dir/$date"
        btrfs subvolume snapshot -r "$latest_dir" "$new_snapshot_dir"
    fi
done
