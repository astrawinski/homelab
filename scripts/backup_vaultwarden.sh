#!/bin/bash

# Quick and Dirty(tm) script to backup and restore Vaultwarden.
# This will not be permanent - it's only being used during early development.

set -e # Exit immediately on error

#!/bin/bash
set -e # Exit immediately on error

# Variables
VAULTWARDEN_DIR="/opt/vaultwarden"
BACKUP_DIR="/media/sf_E_DRIVE/vaultwarden_backup"
DATA_DIR="$VAULTWARDEN_DIR/data"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Try: sudo $0"
    exit 1
fi

# Function to stop Vaultwarden
stop_vaultwarden() {
    echo "Stopping Vaultwarden..."
    cd "$VAULTWARDEN_DIR"
    docker-compose down
}

# Function to start Vaultwarden
start_vaultwarden() {
    echo "Starting Vaultwarden..."
    cd "$VAULTWARDEN_DIR"
    docker-compose up -d
}

# Function to backup Vaultwarden data
backup_vaultwarden() {
    echo "Starting Vaultwarden backup..."
    stop_vaultwarden
    mkdir -p "$BACKUP_DIR"

    echo "Copying data directory..."
    rsync -av --progress "$DATA_DIR" "$BACKUP_DIR/"

    echo "Backup completed successfully!"
    start_vaultwarden
}

# Function to restore Vaultwarden data
restore_vaultwarden() {
    echo "Restoring Vaultwarden from backup..."
    stop_vaultwarden

    echo "Restoring data directory..."
    rsync -av --progress "$BACKUP_DIR/data" "$VAULTWARDEN_DIR/"

    echo "Setting correct permissions..."
    chown -R root:root "$DATA_DIR" "$SSL_DIR"

    echo "Restore completed successfully!"
    start_vaultwarden
}

# Menu
echo "Select an option:"
echo "1) Backup Vaultwarden"
echo "2) Restore Vaultwarden from backup"
echo "3) Exit"
read -pr "Enter choice: " choice

case $choice in
1) backup_vaultwarden ;;
2) restore_vaultwarden ;;
3)
    echo "Exiting..."
    exit 0
    ;;
*)
    echo "Invalid choice! Exiting..."
    exit 1
    ;;
esac
