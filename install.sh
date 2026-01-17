#!/bin/bash
set -e

DISK="/dev/sda"
HOSTNAME="arch-kde"
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"

echo "==> Arch Linux Minimal KDE Install"
sleep 2

# ----------------------------
# Disk partitioning
# ----------------------------
echo "==> Partitioning disk: $DISK"

sgdisk --zap-all $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" $DISK
sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" $DISK

mkfs.fat -F32 ${DISK}1
mkfs.ext4 -F ${DISK}2

mount ${DISK}2 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot

# ----------------------------
# Base install
# ----------------------------
echo "==> Installing base system"

pacstrap /mnt \
  base linux linux-firmware intel-ucode \
  networkmanager iwd \
  sudo vim git \
  pipewire pipewire-pulse wireplumber \
  plasma-desktop plasma-wayland-session \
  konsole dolphin kate \
  sddm \
  mesa vulkan-intel xf86-video-intel

genfstab -U /mnt >> /mnt/etc/fstab

# ----------------------------
# Chroot configuration
# ----------------------------
arch-chroot /mnt /bin/bash <<EOF

set -e

echo "$HOSTNAME" > /etc/hostname

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/#$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Network
systemctl enable NetworkManager

# Display manager
systemctl enable sddm

# PipeWire
systemctl --user enable pipewire pipewire-pulse wireplumber || true

# ----------------------------
# Bootloader (systemd-boot)
# ----------------------------
bootctl install

UUID=\$(blkid -s PARTUUID -o value ${DISK}2)

cat > /boot/loader/loader.conf <<BOOT
default arch
timeout 3
editor no
BOOT

cat > /boot/loader/entries/arch.conf <<BOOT
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=\$UUID rw quiet splash
BOOT

# ----------------------------
# User creation (INTERACTIVE)
# ----------------------------
echo
echo "==> Create your user"
read -p "Username: " USERNAME
useradd -m -G wheel -s /bin/bash \$USERNAME
passwd \$USERNAME

echo
read -p "Grant sudo access to \$USERNAME? (y/n): " SUDO

if [[ "\$SUDO" == "y" ]]; then
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi

# Root password
echo
echo "==> Set root password"
passwd

EOF

echo
echo "==> INSTALL COMPLETE"
echo "Reboot, remove ISO, enjoy your minimal KDE Wayland system."
