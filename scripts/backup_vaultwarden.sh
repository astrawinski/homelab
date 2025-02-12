#!/bin/bash

# Quick and Dirty(tm) script to backup and restore Vaultwarden.
# This will not be permanent - it's only being used during early development.

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
    rsync -av --progress "$DATA_DIR/" "$BACKUP_DIR/"

    echo "Backup completed successfully!"
    start_vaultwarden
}

# Function to restore Vaultwarden data
restore_vaultwarden() {
    echo "Restoring Vaultwarden from backup..."
    stop_vaultwarden

    echo "Restoring data directory..."
    rsync -av --progress "$BACKUP_DIR/data/" "$DATA_DIR/"

    echo "Setting correct permissions..."
    chown -R root:root "$DATA_DIR"

    echo "Restore completed successfully!"
    start_vaultwarden
}

# Display usage information
usage() {
    echo "Usage: $0 {backup|restore}"
    echo "  backup   - Creates a backup of Vaultwarden data in $BACKUP_DIR"
    echo "  restore  - Restores Vaultwarden data from $BACKUP_DIR"
    exit 1
}

# Validate command-line arguments
if [[ $# -ne 1 ]]; then
    usage
fi

case "$1" in
    backup) backup_vaultwarden ;;
    restore) restore_vaultwarden ;;
    *) usage ;;
esac
