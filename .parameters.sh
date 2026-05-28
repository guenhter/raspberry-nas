#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
ENV_FILE="$SCRIPT_DIR/.env"
DEFAULT_DISK_FULL_MOUNT_PATH="/mnt/backup"

function load_env_file() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
}

function get_root_device_parent() {
    local root_source
    local root_device
    local parent_device

    root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    root_device=$(readlink -f -- "$root_source" 2>/dev/null || true)

    if [ -n "$root_device" ]; then
        parent_device=$(lsblk -no PKNAME "$root_device" 2>/dev/null | head -n 1)
        if [ -n "$parent_device" ]; then
            printf '/dev/%s\n' "$parent_device"
            return
        fi
        printf '%s\n' "$root_device"
    fi
}

function collect_disk_uuid_candidates() {
    local root_parent
    local uuid_path
    local resolved_path
    local parent_device
    local fs_type

    root_parent=$(get_root_device_parent)

    for uuid_path in /dev/disk/by-uuid/*; do
        [ -e "$uuid_path" ] || continue

        resolved_path=$(readlink -f -- "$uuid_path" 2>/dev/null || true)
        [ -b "$resolved_path" ] || continue

        fs_type=$(lsblk -no FSTYPE "$resolved_path" 2>/dev/null | head -n 1)
        [ -n "$fs_type" ] || continue

        parent_device=$(lsblk -no PKNAME "$resolved_path" 2>/dev/null | head -n 1)
        if [ -n "$root_parent" ] && [ -n "$parent_device" ] && [ "/dev/$parent_device" = "$root_parent" ]; then
            continue
        fi

        printf '%s|%s|%s\n' "$uuid_path" "$resolved_path" "$fs_type"
    done
}

function prompt_disk_full_uuid_path() {
    local candidates=()
    local index=1
    local selection
    local entry
    local uuid_path
    local resolved_path
    local fs_type

    mapfile -t candidates < <(collect_disk_uuid_candidates)

    printf '\n== Select NAS disk ==\n'
    if [ "${#candidates[@]}" -eq 0 ]; then
        printf 'No external filesystem candidates were found automatically.\n'
        while true; do
            read -r -p 'Enter DISK_FULL_UUID_PATH manually: ' selection
            if [ -n "$selection" ]; then
                DISK_FULL_UUID_PATH="$selection"
                return
            fi
        done
    fi

    for entry in "${candidates[@]}"; do
        IFS='|' read -r uuid_path resolved_path fs_type <<< "$entry"
        printf '%s) %s -> %s [%s]\n' "$index" "$uuid_path" "$resolved_path" "$fs_type"
        index=$((index + 1))
    done

    while true; do
        read -r -p 'Choose the NAS disk by number: ' selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#candidates[@]}" ]; then
            IFS='|' read -r uuid_path _ <<< "${candidates[$((selection - 1))]}"
            DISK_FULL_UUID_PATH="$uuid_path"
            return
        fi
        printf 'Invalid selection. Choose a number from the list.\n'
    done
}

function prompt_disk_full_mount_path() {
    local input_path

    while true; do
        read -r -p "Enter DISK_FULL_MOUNT_PATH [$DEFAULT_DISK_FULL_MOUNT_PATH]: " input_path
        input_path=${input_path:-$DEFAULT_DISK_FULL_MOUNT_PATH}
        input_path=${input_path%/}

        if [ -n "$input_path" ] && [[ "$input_path" == /* ]]; then
            DISK_FULL_MOUNT_PATH="$input_path"
            return
        fi

        printf 'The mount path must be an absolute path.\n'
    done
}

function write_env_file() {
    cat > "$ENV_FILE" <<EOL
DISK_FULL_UUID_PATH="$DISK_FULL_UUID_PATH"
DISK_FULL_MOUNT_PATH="$DISK_FULL_MOUNT_PATH"
EOL
}

function ensure_parameters() {
    if [ -z "$DISK_FULL_UUID_PATH" ]; then
        if [ ! -t 0 ]; then
            printf 'Missing required parameter and no TTY available to prompt: DISK_FULL_UUID_PATH\n' >&2
            return 1
        fi
        prompt_disk_full_uuid_path
        write_env_file
        printf '\nSaved parameters to %s\n' "$ENV_FILE"
    fi

    if [ -z "$DISK_FULL_MOUNT_PATH" ]; then
        if [ ! -t 0 ]; then
            printf 'Missing required parameter and no TTY available to prompt: DISK_FULL_MOUNT_PATH\n' >&2
            return 1
        fi
        prompt_disk_full_mount_path
        write_env_file
        printf '\nSaved parameters to %s\n' "$ENV_FILE"
    fi

    export DISK_FULL_UUID_PATH DISK_FULL_MOUNT_PATH
}

load_env_file
ensure_parameters
