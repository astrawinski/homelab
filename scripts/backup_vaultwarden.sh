#!/bin/bash
set -e  # Exit immediately on error

# Variables
VAULTWARDEN_DIR="/opt/vaultwarden"
VAULTWARDEN_DATA_DIR="$VAULTWARDEN_DIR/data"
BACKUP_DIR="/media/sf_E_DRIVE/vaultwarden_backup"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Try: sudo $0"
    exit 1
fi

# Function to check if Docker is installed
is_docker_installed() {
    command -v docker >/dev/null 2>&1
}

# Function to check if Vaultwarden is running
is_vaultwarden_running() {
    is_docker_installed && docker ps --format '{{.Names}}' | grep -q "vaultwarden_vaultwarden_1"
}

# Function to stop Vaultwarden (only if it's running)
stop_vaultwarden() {
    if is_vaultwarden_running; then
        echo "Stopping Vaultwarden..."
        cd "$VAULTWARDEN_DIR"
        docker-compose down
    else
        echo "Vaultwarden is not running. Skipping stop step."
    fi
}

# Function to start Vaultwarden (only if Docker is installed)
start_vaultwarden() {
    if is_docker_installed; then
        echo "Starting Vaultwarden..."
        cd "$VAULTWARDEN_DIR"
        docker-compose up -d
    else
        echo "Docker is not installed. Skipping start step."
    fi
}

# Function to backup Vaultwarden data
backup_vaultwarden() {
    echo "Starting Vaultwarden backup..."
    stop_vaultwarden
    mkdir -p "$BACKUP_DIR"

    echo "Copying data directory..."
    rsync -av --progress "$VAULTWARDEN_DATA_DIR" "$BACKUP_DIR/"

    echo "✅ Backup completed successfully!"
    start_vaultwarden
}

# Function to restore Vaultwarden data
restore_vaultwarden() {
    echo "Restoring Vaultwarden from backup..."
    
    # Ensure Vaultwarden data directory exists
    if [[ ! -d "$VAULTWARDEN_DATA_DIR" ]]; then
        echo "Vaultwarden data directory is missing. Creating it..."
        mkdir -p "$VAULTWARDEN_DATA_DIR"
    fi

    stop_vaultwarden

    echo "Restoring data directory..."
    rsync -av --progress "$BACKUP_DIR/data/" "$VAULTWARDEN_DATA_DIR/"

    echo "Setting correct permissions..."
    chown -R root:root "$VAULTWARDEN_DATA_DIR"

    echo "✅ Restore completed successfully!"
    start_vaultwarden
}

# Parse command-line arguments
usage() {
    echo "Usage: $0 [-b|--backup] [-r|--restore]"
    echo "  -b, --backup   Backup Vaultwarden data"
    echo "  -r, --restore  Restore Vaultwarden from backup"
    exit 1
}

if [[ $# -eq 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--backup)
            backup_vaultwarden
            shift
            ;;
        -r|--restore)
            restore_vaultwarden
            shift
            ;;
        *)
            usage
            ;;
    esac
done
