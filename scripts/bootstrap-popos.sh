#!/bin/bash

set -x  # Print each command before executing
set -e  # Stop the script on uncaught errors

# Ensure /media/pop-os/persist is mounted
if mount | grep -q "/media/pop-os/persist"; then
  sudo rsync -axHAX --info=progress2 /media/pop-os/persist/ /home/pop-os/
else
  echo "Persistence partition not mounted!"
  exit 1
fi

# Identify the correct disk with lsblk
DISK="/dev/nvme0n1"
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

# Ensure /mnt is clean before proceeding
sudo umount -Rl /mnt 2>/dev/null || true

# Unmount EFI if mounted
if mount | grep -q "$EFI_PART"; then
  sudo umount "$EFI_PART"
fi

# Wipe Disk
sudo wipefs --all --force "$DISK"
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
for sub in @ @home @var @log @cache @snapshots @swap; do
  sudo btrfs subvolume create /mnt/$sub
done
sudo umount /mnt

# Mount Btrfs Subvolumes
sudo mount -o noatime,compress=zstd,subvol=@ "$ROOT_PART" /mnt
sudo mkdir -p /mnt/{boot,home,var,log,cache,.snapshots,swap}
for sub in home var log cache .snapshots swap; do
  if [[ "$sub" == ".snapshots" ]]; then
    subvolume="@snapshots"  # Handle snapshots without the dot
  else
    subvolume="@${sub}"
  fi
  sudo mount -o noatime,compress=zstd,subvol=$subvolume "$ROOT_PART" /mnt/$sub
done


# Create Swap File (inside the @swap subvolume)
sudo losetup -D  # Ensure no stale loop devices
sudo truncate -s 8G /mnt/swap/swapfile
sudo chmod 600 /mnt/swap/swapfile
sudo losetup -fP /mnt/swap/swapfile
SWAP_DEVICE=$(losetup -j /mnt/swap/swapfile | cut -d: -f1)
sudo mkswap "$SWAP_DEVICE"
sudo swapon "$SWAP_DEVICE"

# Mount EFI Partition
sudo mkdir -p /mnt/boot/efi
sudo mount "$EFI_PART" /mnt/boot/efi

# Bind Virtual Filesystems
for dir in dev dev/pts proc sys run; do
  sudo mkdir -p /mnt/$dir  # Create the directories if they don't exist
  sudo mount --bind /$dir /mnt/$dir
done

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

# Chroot Configuration
sudo chroot /mnt bash <<'EOF'
set -x
set -e

# Bootloader Install
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
bootctl install
bootctl update

# Create Boot Entry
echo 'title Pop!_OS' > /boot/efi/loader/entries/pop_os.conf
echo -e 'linux /vmlinuz\ninitrd /initrd.img\noptions root=UUID=$(blkid -s UUID -o value /dev/nvme0n1p2) rw quiet splash' >> /boot/efi/loader/entries/pop_os.conf

# System Configurations
echo 'wsub-lap01' > /etc/hostname
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen

# User Setup
useradd -m -G sudo -s /bin/bash subnet
echo 'subnet:password' | chpasswd
echo 'subnet ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/subnet

# Cleanup and exit chroot
exit
EOF

# Unmount Filesystems
sudo umount -Rl /mnt

# Persist Changes to USB
sudo rsync -axHAX --delete --info=progress2 /home/pop-os/ /media/pop-os/persist/

