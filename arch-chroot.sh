#!/bin/bash
set -x

USER="${1}"
DISK="${2}"
TZ="${3}"
GH="${4}"


# Install packages
pacman -S --noconfirm \
    linux \
    linux-headers \
    openssh base-devel \
    networkmanager \
    wpa_supplicant \
    wireless_tools \
    netctl dialog \
    lvm2 \
    efibootmgr \
    dosfstools \
    os-prober \
    mtools \
    intel-ucode \
    zsh \
    python-pip \
    docker \
    docker-compose \
    git
pip install ssh-import-id
# Enable services 
systemctl enable sshd
systemctl enable NetworkManager
systemctl enable docker
# Set kernel parameters
sed -i 's/block filesystems/block lvm2 filesystems/g' /etc/mkinitcpio.conf
mkinitcpio -p linux
# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
# Set timezone
ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
hwclock --systohc
# Set hostname
hostnamectl set-hostname frodo
# Create user and import SSH key
useradd -m -g users -G wheel $USER
echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo
runuser -l $USER -c 'ssh-import-id gh:${GH}'
# Install bootloader
bootctl install
cat <<DEFAULTBOOT > /boot/loader/loader.conf
default arch-*.conf
timeout 4
DEFAULTBOOT
cat <<ARCHBOOT > /boot/loader/entries/arch-latest.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root="/dev/vg0/root" rw
ARCHBOOT
bootctl update
cat <<SETUEFI > /etc/systemd/system/setuefi.service
[Unit]
Description=Set PXE as default EFI boot option
 
[Service]
ExecStart=efibootmgr -n 0005
 
[Install]
WantedBy=multi-user.target
SETUEFI
systemctl enable setuefi
# Add dotfiles
chsh -s /usr/bin/zsh $USER
runuser -l $USER -c '\
    echo ".dot" >> .gitignore && \
    git clone --recursive https://github.com/m-bers/dotfiles.git /home/$USER/.dot && \
    alias dot='/usr/bin/git --git-dir=/home/$USER/.dot/.git --work-tree=/home/$USER' && \
    dot config --local status.showUntrackedFiles no && \
    dot checkout /home/$USER && \
    dot submodule update --recursive
' 
