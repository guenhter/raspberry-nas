#!/bin/bash

set -e

HD_IDLE_VERSION=1.21

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

function disable_sudo_without_password() {
    printf "\n== Removing /etc/sudoers.d files with NOPASSWD ==\n"
    find /etc/sudoers.d -type f -exec grep -l 'NOPASSWD' {} \; | xargs -r rm
}

function configure_basic_ssh() {
    printf "\n== Configure basic ssh settings ==\n"
    SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
    CONF_FILE="$SSHD_CONFIG_DIR/20-backup.conf"
    mkdir -p "$SSHD_CONFIG_DIR"
    if [ -f "$CONF_FILE" ]; then
        echo "SSH configuration file $CONF_FILE already exists. Skipping."
        return
    fi
    tee "$CONF_FILE" > /dev/null <<EOF
PermitEmptyPasswords no
PermitRootLogin no
EOF
    echo "Configured SSH by adding $CONF_FILE."
    systemctl reload ssh || true
}

function update_system() {
    printf "\n== Updating System ==\n"

    apt-get -y update
    apt-get -y upgrade
    apt-get -y autoremove
    apt-get -y autoclean
}

function install_apt_software() {
    printf "\n== Installing Apt Software ==\n"

    apt-get -y install \
        btrfs-progs \
        unattended-upgrades \
        wget \
        hdparm \
        htop \
        vim \
        smartmontools

    ## Needed packages
    # "btrfs-progs" needed to access btrfs and make snapshots
    # "unattended-upgrades" needed for periodic updtes of the system
    # "wget" needed in this script
    # "hdparm" needed to set drive power settings

    ## Optional packages
    # "htop" useful for troubleshooting
    # "vim" useful when editing a file is needed
    # "smartmontools" useful for troubleshooting
}

function configure_unattended_upgrades() {
    printf "\n== Configuring Unattended Upgrades ==\n"

    local auto_config_file="/etc/apt/apt.conf.d/21auto-upgrades"
    local unattended_upgrades_config_file="/etc/apt/apt.conf.d/51unattended-upgrades"

    echo "Configuring unattended-upgrades for automatic updates..."

    tee "$auto_config_file" > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    tee "$unattended_upgrades_config_file" > /dev/null <<'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=*";
};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Verbose "true";
EOF

    systemctl daemon-reload
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    echo "Unattended-upgrades configured"
}


function install_and_configure_hd_idle() {
    printf "\n== Installing hd-idle ==\n"
    HD_IDLE_FILE=hd-idle_${HD_IDLE_VERSION}_armhf.deb
    wget -nc -O /usr/local/src/$HD_IDLE_FILE "https://github.com/adelolmo/hd-idle/releases/download/v${HD_IDLE_VERSION}/${HD_IDLE_FILE}" || true

    if ! dpkg-query -W | grep hd-idle | grep ${HD_IDLE_VERSION}; then
        dpkg -i /usr/local/src/$HD_IDLE_FILE
    fi

    sed -i 's/START_HD_IDLE=.*/START_HD_IDLE=true/' /etc/default/hd-idle
    sed -i 's/.*HD_IDLE_OPTS=.*/HD_IDLE_OPTS="-i 1200 -c ata"/' /etc/default/hd-idle

    systemctl daemon-reload
    systemctl start hd-idle
    systemctl enable hd-idle
}

disable_sudo_without_password
configure_basic_ssh
update_system
install_apt_software
configure_unattended_upgrades
install_and_configure_hd_idle

if [ -f /var/run/reboot-required ]; then
    printf "Rebooting now\n"
    reboot
fi
