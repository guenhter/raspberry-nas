#!/bin/bash

set -e

HD_IDLE_VERSION=1.21

function disable_sudo_without_password() {
    printf "\n== Removing /etc/sudoers.d files with NOPASSWD ==\n"
    find /etc/sudoers.d -type f -exec grep -l 'NOPASSWD' {} \; | xargs -r rm
}

function configure_basic_ssh() {
    printf "\n== Configure basic ssh settings ==\n"

    sed -i 's/.*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

    systemctl restart sshd
}

function update_system() {
    printf "\n== Updating System ==\n"

    apt-get -y update
    apt-get -y upgrade
    apt-get -y autoremove
    apt-get -y autoclean

    if [ -f /var/run/reboot-required ]; then
        printf "Rebooting now\n"
    fi
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

    sed -i 's/.*Unattended-Upgrade::Automatic-Reboot .*/Unattended-Upgrade::Automatic-Reboot "true";/' /etc/apt/apt.conf.d/50unattended-upgrades
    sed -i 's/.*Unattended-Upgrade::Automatic-Reboot-Time .*/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/' /etc/apt/apt.conf.d/50unattended-upgrades

    systemctl restart unattended-upgrades
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
