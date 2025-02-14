#!/bin/bash

set -x  # Print each command before executing
set -e  # Stop the script on uncaught errors

# Ensure /media/pop-os/persist is mounted
if mount | grep -q "/media/pop-os/persist"; then
  # Copy contents from the USB drive to /home/pop-os
<<<<<<< HEAD
  sudo rsync -axHAX --info=progress2 /media/pop-os/persist/ /home/pop-os/
else
  echo "Persistence partition not mounted!"
  exit 1
fi

# Identify the correct disk with lsblk, then Modify if needed.
=======
  sudo rsync -axHAX --delete --info=progress2 /media/pop-os/persist/ /home/pop-os/
else
  echo "Persistence partition not mounted!"
fi

exit

# Identify your disk with lsblk, then Modify if needed.
>>>>>>> caf1c4a929a7ab9671c2124fd2f32c44cd44a48f
DISK="/dev/nvme0n1"
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

# Wipe the Disk
sudo wipefs --all "$DISK"
sudo sgdisk --zap-all "$DISK"

# Create GPT Partition Table
sudo parted "$DISK" -- mklabel gpt

# Create EFI Partition and Filesystem
sudo parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
sudo parted "$DISK" -- set 1 esp on
sudo mkfs.fat -F32 "$EFI_PART"

# Create Btrfs Partition and Filesystem
sudo parted "$DISK" -- mkpart primary btrfs 1GiB 100%
sudo mkfs.btrfs -L POP_OS_ROOT "$ROOT_PART" -f

# Create Btrfs Subvolumes
sudo mount "$ROOT_PART" /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@log
sudo btrfs subvolume create /mnt/@cache
sudo btrfs subvolume create /mnt/@snapshots
sudo btrfs subvolume create /mnt/@var
sudo btrfs subvolume create /mnt/@swap
sudo umount /mnt

# Mount Btrfs Subvolumes
sudo mount -o noatime,compress=zstd,subvol=@ "$ROOT_PART" /mnt
sudo mkdir -p /mnt/{boot,home,var,log,cache,.snapshots,swap}
sudo mount -o noatime,compress=zstd,subvol=@home "$ROOT_PART" /mnt/home
sudo mount -o noatime,compress=zstd,subvol=@var "$ROOT_PART" /mnt/var
sudo mount -o noatime,compress=zstd,subvol=@log "$ROOT_PART" /mnt/log
sudo mount -o noatime,compress=zstd,subvol=@cache "$ROOT_PART" /mnt/cache
sudo mount -o noatime,compress=zstd,subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
sudo mount -o noatime,compress=zstd,subvol=@swap "$ROOT_PART" /mnt/swap

# Create Swap File
sudo truncate -s 8G /mnt/swap/swapfile
sudo chmod 600 /mnt/swap/swapfile
sudo losetup -fP /mnt/swap/swapfile
SWAP_DEVICE=$(losetup -j /mnt/swap/swapfile | cut -d: -f1)
sudo mkswap "$SWAP_DEVICE"
sudo swapon "$SWAP_DEVICE"

# Mount EFI Partition
sudo mkdir -p /mnt/boot/efi
sudo mount "$EFI_PART" /mnt/boot/efi

# Bind mount virtual filesystems inside chroot
sudo mkdir -p /mnt/{dev,proc,sys,run}
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /run /mnt/run

# Extract Pop!_OS from ISO
sudo unsquashfs /cdrom/casper/filesystem.squashfs
sudo mkdir -p /mnt/rootfs
sudo mv squashfs-root /mnt/rootfs
sudo rsync -axHAX --info=progress2 /mnt/rootfs/squashfs-root/ /mnt/

# Get UUIDs
ROOT_UUID=$(sudo blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(sudo blkid -s UUID -o value "$EFI_PART")

# Generate fstab
echo "# Generated fstab" | sudo tee /mnt/etc/fstab
echo "UUID=$ROOT_UUID / btrfs defaults,noatime,compress=zstd 0 0" | sudo tee -a /mnt/etc/fstab
echo "UUID=$EFI_UUID /boot/efi vfat defaults 0 0" | sudo tee -a /mnt/etc/fstab

# Chroot into new system and configure
sudo chroot /mnt bash <<'EOF'
  set -x
  set -e

  # Bootloader Install
  bootctl install --no-variables

  # Create Boot Entry
  echo 'title Pop!_OS' > /boot/efi/loader/entries/pop_os.conf
  echo -e 'linux /vmlinuz\ninitrd /initrd.img\noptions root=UUID=$ROOT_UUID rw quiet splash' >> /boot/efi/loader/entries/pop_os.conf

  # Configure hostname and locale
  echo 'wsub-lap01' > /etc/hostname
  ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
  dpkg-reconfigure -f noninteractive tzdata
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  locale-gen
  echo 'LANG=en_US.UTF-8' > /etc/default/locale

  # Create a user and configure sudo
  useradd -m -G sudo -s /bin/bash subnet
  echo 'subnet:password' | chpasswd
  echo 'subnet ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/subnet

  # Set up network
  echo 'nameserver 1.1.1.1' > /etc/resolv.conf
EOF

# Unmount filesystems
sudo umount -Rl /mnt
# Persist home directory changes to USB
sudo rsync -axHAX --delete --info=progress2 /home/pop-os/ /media/pop-os/persist/

# Final reboot (optional)
# sudo reboot

<<<<<<< HEAD
=======
    # Enable DNS
    echo "nameserver 1.1.1.1" > /etc/resolv.conf

    # Update Packages
    #apt update
    #apt upgrade -y
    #apt full-upgrade -y

    # Enable Necessary Services
    #systemctl enable systemd-timesyncd   # Time synchronization
    #systemctl enable thermald             # CPU thermal management (for laptops)
    #systemctl enable systemd-resolved     # DNS resolution
    #systemctl enable NetworkManager       # Networking

    # Enable SSH
    #systemctl enable ssh

    # Rebuild Initramfs (ensure proper boot setup)
    update-initramfs -u -k all
"

# Persist home directory changes to USB
sudo rsync -axHAX --delete --info=progress2 /home/pop-os/ /media/pop-os/persist/

# Cleanup and Reboot
#sudo umount -R /mnt
#sudo reboot
>>>>>>> caf1c4a929a7ab9671c2124fd2f32c44cd44a48f

