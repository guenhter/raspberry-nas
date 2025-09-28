#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

SCRIPT_DIR=$(dirname -- "$( readlink -f -- "$0"; )")

if [ ! -f "$SCRIPT_DIR/parameters.sh" ]; then
    printf "Canont load parameters from ./parameters.sh\n"
    exit 1
fi

printf "\n== Loading parameters ==\n"
source "$SCRIPT_DIR/parameters.sh"

if [ -z "$DISK_FULL_UUID_PATH" ] || [ -z "$DISK_FULL_MOUNT_PATH" ]; then
    printf "Not all required variables defined in the parameters file.\n"
    exit 1
fi


function setup_disk_automount() {
    printf "\n== Automount disk ==\n"

    # Remove trailing slash
    DISK_FULL_MOUNT_PATH="${DISK_FULL_MOUNT_PATH%/}"

    # Remove leading slash and then replace "/" with "-"
    systemd_service_prefix="${DISK_FULL_MOUNT_PATH#/}"
    systemd_service_prefix="${systemd_service_prefix//\//-}"

    mkdir -p "$DISK_FULL_MOUNT_PATH"



    cat >"/etc/systemd/system/$systemd_service_prefix.mount" <<EOF
[Unit]
Description=Mount $DISK_FULL_UUID_PATH

[Mount]
Where=$DISK_FULL_MOUNT_PATH
What=$DISK_FULL_UUID_PATH
Type=btrfs
Options=defaults,nofail

[Install]
WantedBy=multi-user.target
EOF



cat >"/etc/systemd/system/$systemd_service_prefix.automount" <<EOF
[Unit]
Description=Automount $DISK_FULL_UUID_PATH

[Automount]
Where=$DISK_FULL_MOUNT_PATH
TimeoutIdleSec=300

[Install]
WantedBy=multi-user.target
EOF



    systemctl daemon-reload
    systemctl start "$systemd_service_prefix.automount"
    systemctl enable "$systemd_service_prefix.automount"
}

function install_snapshot_cron_script() {
    printf "\n== Installing the script 'create-btrfs-snapshot.sh' as cron ==\n"

    mkdir -p /opt/
    cp "$SCRIPT_DIR/create-btrfs-snapshot.sh" /opt/

    cat >"/etc/cron.d/sftp-disk-snapthots" <<EOF
30 3 * * 0 root /opt/create-btrfs-snapshot.sh "$DISK_FULL_MOUNT_PATH"
EOF
}

function configure_ssh_for_sftp() {
    printf "\n== Configure SSH for SFTP ==\n"

    sed -i '/^\s*Subsystem\s*sftp/ s/^/#/' /etc/ssh/sshd_config

    # Create samba group
    getent group backupusers || groupadd backupusers

    cat >"/etc/ssh/sshd_config.d/sftp.conf" <<EOF
Subsystem sftp internal-sftp

Match Group backupusers
	X11Forwarding no
	AllowTcpForwarding no
	ChrootDirectory $DISK_FULL_MOUNT_PATH/sftp/%u
	ForceCommand internal-sftp
EOF

    systemctl restart sshd
}

function install_and_configure_samba() {
    printf "\n== Installing and configuring Samba ==\n"

    # Install Samba
    apt-get update
    apt-get install -y samba samba-common-bin

    # Create samba group
    getent group backupusers || groupadd backupusers

    # Backup original smb.conf
    if [ ! -f /etc/samba/smb.conf.backup ]; then
        cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
    fi

    # Create basic Samba configuration
    cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = Raspberry Pi NAS
   security = user
   encrypt passwords = yes
   guest account = nobody
   map to guest = never
   create mask = 0664
   directory mask = 0775
   force create mode = 0664
   force directory mode = 0775
   load printers = no
   disable spoolss = yes
   printing = bsd
   printcap name = /dev/null

# User-specific share configurations will be included below
EOF

    # Create directory for modular configurations
    mkdir -p /etc/samba/conf.d

    # Enable and start Samba services
    systemctl enable smbd
    systemctl enable nmbd
    systemctl start smbd
    systemctl start nmbd

    # Configure firewall if ufw is active
    if systemctl is-active --quiet ufw; then
        ufw allow samba
    fi
}


setup_disk_automount
install_and_configure_samba
configure_ssh_for_sftp
install_snapshot_cron_script
