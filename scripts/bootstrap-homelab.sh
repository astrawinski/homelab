#!/bin/bash

set -x  # Print each command before executing
set -e  # Stop the script on uncaught errors

# Configure Git
git config --global user.email "alan@strawinski.net"
git config --global user.name "Alan Strawinski"

# Setup Temporary SSH Key for GitHub Authentication
mkdir -p ~/.ssh
[[ -f ~/.ssh/id_ed25519 ]] || ssh-keygen -t ed25519 -C "live-session" -f ~/.ssh/id_ed25519 -N ""

echo "Add this SSH key to GitHub: https://github.com/settings/ssh"
cat ~/.ssh/id_ed25519.pub
read -p 'Press Enter after adding the key to GitHub...' 

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

# Create Partitions
sudo parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
sudo parted "$DISK" -- set 1 esp on
sudo mkfs.fat -F32 "$EFI_PART"

sudo parted "$DISK" -- mkpart primary btrfs 1GiB 100%
udo mkfs.btrfs -L POP_OS_ROOT "$ROOT_PART" -f

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

# Verify fstab
blkid

echo "Installation setup complete! Proceed with manual configurations."


