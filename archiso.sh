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
pvcreate --dataalignment 1m "${DISK}2"
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

arch-chroot /mnt curl https://raw.githubusercontent.com/m-bers/arch-unattended/main/arch-chroot.sh | bash
umount -a 
reboot
