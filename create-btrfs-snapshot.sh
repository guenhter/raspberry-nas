#!/bin/bash

DISK_FULL_MOUNT_PATH="$1"

if [ -z "$DISK_FULL_MOUNT_PATH" ]; then
  echo "Usage: $0 [DISK_FULL_MOUNT_PATH]"
  echo "  e.g. $0 /mnt/disk1"
  exit 1
fi

# Remove trailing slashes
DISK_FULL_MOUNT_PATH="${DISK_FULL_MOUNT_PATH%/}"

for user_dir in "$DISK_FULL_MOUNT_PATH"/sftp/*/; do
    # Remove trailing slashes
    user_dir="${user_dir%/}"

    latest_dir="$user_dir/latest"
    snapshots_dir="$user_dir/snapshots"

    if [ ! -d "$latest_dir" ] || [ ! -d "$snapshots_dir" ]; then
        echo "Skipping backup because not all folders exists for $user_dir"
    else
        date=$(date '+%Y-%m-%d')
        new_snapshot_dir="$snapshots_dir/$date"
        echo "Create snapshot for '$latest_dir' to '$new_snapshot_dir'"
        btrfs subvolume snapshot -r "$latest_dir" "$new_snapshot_dir"
    fi
done
