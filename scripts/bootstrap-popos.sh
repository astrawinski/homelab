#!/bin/bash

set -x  # Print each command before executing
set -e  # Stop the script on uncaught errors

sudo rsync -avh --progress /home/pop-os/ /media/pop-os/persist/home/pop-os


# Configure Git
git config --global user.email "alan@strawinski.net"
git config --global user.name "Alan Strawinski"

# Setup Temporary SSH Key for GitHub Authentication
mkdir -p ~/.ssh
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
    ssh-keygen -t ed25519 -C "live-session" -f ~/.ssh/id_ed25519 -N ""
    echo "Add this SSH key to GitHub: https://github.com/settings/ssh"
    cat ~/.ssh/id_ed25519.pub
    read -p 'Press Enter after adding the key to GitHub...'
fi

# Configure GitHub to use ssh
git remote set-url origin git@github.com:astrawinski/homelab.git || true

# Identify your disk with lsblk, then Modify if needed.
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

# Extract Pop!_OS from ISO
sudo unsquashfs /cdrom/casper/filesystem.squashfs
sudo mkdir -p /mnt/rootfs
sudo mv squashfs-root /mnt/rootfs
sudo rsync -axHAX --info=progress2 /mnt/rootfs/squashfs-root/ /mnt/

# Get UUIDs
ROOT_UUID=$(sudo blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(sudo blkid -s UUID -o value "$EFI_PART")

# Generate fstab
echo "# Generated fstab" | sudo tee /mnt/etc/fstab &&

echo "UUID=$ROOT_UUID / btrfs defaults,noatime,compress=zstd,subvol=@ 0 1" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$ROOT_UUID /home btrfs defaults,noatime,compress=zstd,subvol=@home 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$ROOT_UUID /var btrfs defaults,noatime,compress=zstd,subvol=@var 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$ROOT_UUID /log btrfs defaults,noatime,compress=zstd,subvol=@log 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$ROOT_UUID /cache btrfs defaults,noatime,compress=zstd,subvol=@cache 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$ROOT_UUID /.snapshots btrfs defaults,noatime,compress=zstd,subvol=@snapshots 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$ROOT_UUID /swap btrfs defaults,noatime,subvol=@swap 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "UUID=$EFI_UUID /boot/efi vfat defaults 0 2" | sudo tee -a /mnt/etc/fstab &&
echo "/swap/swapfile none swap sw 0 0" | sudo tee -a /mnt/etc/fstab

# Run system configuration inside chroot without stopping the script
sudo chroot /mnt bash -c "
    set -x
    set -e

    # Install Bootloader
    bootctl install --no-variables

    # Create Boot Entry
    echo 'title Pop!_OS' | tee /boot/efi/loader/entries/pop_os.conf
    echo -e 'linux /vmlinuz\ninitrd /initrd.img\noptions root=UUID=$ROOT_UUID rw quiet splash' | tee -a /boot/efi/loader/entries/pop_os.conf

    # Set System Configurations
    echo 'wsub-lap01' > /etc/hostname

    # Configure Timezone
    ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
    dpkg-reconfigure -f noninteractive tzdata

    # Configure Locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/default/locale
    export LANG=en_US.UTF-8

    # Create User
    useradd -m -G sudo -s /bin/bash subnet
    echo 'subnet:password' | chpasswd
    echo 'subnet ALL=(ALL) NOPASSWD:ALL' | tee /etc/sudoers.d/subnet

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

# Cleanup and Reboot
#sudo umount -R /mnt
#sudo reboot

