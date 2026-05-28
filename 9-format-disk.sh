#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
ENV_FILE="$SCRIPT_DIR/.env"
DEFAULT_MOUNT_PATH="/mnt/backup"

function get_system_disk() {
    local root_source root_device parent
    root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    root_device=$(readlink -f -- "$root_source" 2>/dev/null || true)
    parent=$(lsblk -no PKNAME "$root_device" 2>/dev/null | head -n 1)
    if [ -n "$parent" ]; then
        printf '/dev/%s\n' "$parent"
    else
        printf '%s\n' "$root_device"
    fi
}

system_disk=$(get_system_disk)
candidates=()

while IFS= read -r line; do
    name=$(awk '{print $1}' <<< "$line")
    size=$(awk '{print $2}' <<< "$line")
    type=$(awk '{print $3}' <<< "$line")
    [ "$type" = "disk" ] || continue
    [[ "$name" == /dev/loop* || "$name" == /dev/zram* ]] && continue
    [ "$name" = "$system_disk" ] && continue
    candidates+=("$name|$size")
done < <(lsblk -dpno NAME,SIZE,TYPE)

if [ "${#candidates[@]}" -eq 0 ]; then
    printf 'No external disks found.\n' >&2
    exit 1
fi

printf '\n== Select disk to format ==\n'
index=1
for entry in "${candidates[@]}"; do
    IFS='|' read -r name size <<< "$entry"
    printf '%s) %s (%s)\n' "$index" "$name" "$size"
    index=$((index + 1))
done

while true; do
    read -r -p 'Choose disk by number: ' selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#candidates[@]}" ]; then
        IFS='|' read -r disk_path disk_size <<< "${candidates[$((selection - 1))]}"
        break
    fi
    printf 'Invalid selection.\n'
done

printf '\nSelected: %s (%s)\n' "$disk_path" "$disk_size"
printf '!! WARNING: ALL DATA ON THIS DISK WILL BE LOST !!\n\n'
read -r -p "Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
    printf 'Aborted.\n'
    exit 1
fi

printf '\n== Partitioning %s ==\n' "$disk_path"
parted "$disk_path" --align opt mklabel gpt 0% 100%
parted "$disk_path" --align opt mkpart primary 0% 100%

mkfs.btrfs -f "${disk_path}1"

udevadm settle

new_uuid=$(lsblk -no UUID "${disk_path}1" 2>/dev/null | head -n 1)
if [ -z "$new_uuid" ]; then
    new_uuid=$(blkid -s UUID -o value "${disk_path}1" 2>/dev/null || true)
fi
printf '\nNew filesystem UUID: %s\n' "$new_uuid"

while true; do
    read -r -p "Enter mount path [$DEFAULT_MOUNT_PATH]: " mount_path
    mount_path=${mount_path:-$DEFAULT_MOUNT_PATH}
    mount_path=${mount_path%/}
    if [ -n "$mount_path" ] && [[ "$mount_path" == /* ]]; then
        break
    fi
    printf 'Must be an absolute path.\n'
done

cat > "$ENV_FILE" <<EOL
DISK_FULL_UUID_PATH="/dev/disk/by-uuid/$new_uuid"
DISK_FULL_MOUNT_PATH="$mount_path"
EOL
printf '\nSaved to %s\n' "$ENV_FILE"
