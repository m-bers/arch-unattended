#!/bin/bash
set -x

USER="josh"
DISK="/dev/sda" # 
TZ="America/Los_Angeles" # Timezone
GH="m-bers" # GitHub username (for SSH key import)


# Format $DISK with LVM (500Mb EFI, )
vgremove -y vg0
wipefs --all --force $DISK
echo -e "g\nn\n\n\n+500M\nt\n1\nn\n\n\n\nt\n\n30\nw\n" | fdisk $DISK

mkfs.vfat -F32 "${DISK}1"
pvcreate --force --dataalignment 1m "${DISK}2"
vgcreate vg0 "${DISK}2"
lvcreate -y -L 30GB vg0 -n root
lvcreate -y -L 50GB vg0 -n home
modprobe dm_mod
vgchange -ay
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mount /dev/vg0/root /mnt
mkdir /mnt/home
mount /dev/vg0/home /mnt/home
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot
mkdir /mnt/etc
genfstab -U -p /mnt >> /mnt/etc/fstab
pacstrap /mnt base

cat <<CHROOTSCRIPT > /mnt/arch-chroot.sh
#!/bin/bash
set -x
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
useradd -m -g users -G wheel,docker $USER
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

CHROOTSCRIPT

chmod +x /mnt/arch-chroot.sh
arch-chroot /mnt /arch-chroot.sh
umount -a 
reboot
