#!/bin/bash
set -e  # Exit immediately on error

# Ensure we are running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

# Update system packages
echo "Updating system..."
apt update && apt upgrade -y

# Install required packages
echo "Installing required packages..."
apt install -y docker.io docker-compose ufw git openssh-server openssl

# Enable & start SSH
echo "Configuring SSH..."
systemctl enable ssh
systemctl start ssh
ufw allow OpenSSH
ufw enable

# Ensure /opt/vaultwarden exists
mkdir -p /opt/vaultwarden/data
mkdir -p /opt/vaultwarden/certs

# Check for existing Vaultwarden data
if [ -z "$(ls -A /opt/vaultwarden/data 2>/dev/null)" ]; then
    echo "No existing Vaultwarden data found."
    read -p "Do you have a backup to restore? (y/N) " restore_choice

    if [[ "$restore_choice" =~ ^[Yy]$ ]]; then
        read -p "Enter the path to the backup directory (e.g., /mnt/backup/vaultwarden): " backup_path
        if [ -d "$backup_path" ]; then
            echo "Restoring Vaultwarden data from $backup_path..."
            cp -r "$backup_path"/* /opt/vaultwarden/data/
            echo "Vaultwarden data restored successfully."
        else
            echo "Invalid backup path. Starting fresh."
        fi
    else
        echo "No backup provided. Starting a fresh Vaultwarden instance."
    fi
else
    echo "Existing Vaultwarden data found. Using current data."
fi

# Generate a self-signed SSL certificate if not present
if [[ ! -f /opt/vaultwarden/certs/vaultwarden.crt || ! -f /opt/vaultwarden/certs/vaultwarden.key ]]; then
    echo "Generating a self-signed SSL certificate..."
    openssl req -x509 -newkey rsa:4096 -keyout /opt/vaultwarden/certs/vaultwarden.key \
      -out /opt/vaultwarden/certs/vaultwarden.crt -days 365 -nodes \
      -subj "/CN=wsub-wsl01.internal.strawinski.net"
    echo "SSL certificate generated."
else
    echo "Existing SSL certificate found. Skipping generation."
fi

# Deploy Vaultwarden with Docker Compose
echo "Deploying Vaultwarden..."
cat <<EOF > /opt/vaultwarden/docker-compose.yml
version: '3'
services:
  vaultwarden:
    image: bitwardenrs/server:latest
    restart: unless-stopped
    volumes:
      - /opt/vaultwarden/data:/data
      - /opt/vaultwarden/certs:/certs
    ports:
      - "443:443"
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
      - ROCKET_TLS={certs="/certs/vaultwarden.crt",key="/certs/vaultwarden.key"}
EOF

# Restart Vaultwarden
cd /opt/vaultwarden
docker-compose down
docker-compose up -d

echo "Vaultwarden is now running with HTTPS. Access it at:"
echo "  https://wsub-wsl01.internal.strawinski.net"

# Generate SSH key for ansible user
echo "Creating ansible user and SSH key..."
useradd -m -s /bin/bash ansible || echo "User ansible already exists."
mkdir -p /home/ansible/.ssh
ssh-keygen -t ed25519 -f /home/ansible/.ssh/id_ed25519 -N ""
chown -R ansible:ansible /home/ansible/.ssh

echo "Done! Now copy the SSH key to your workstation:"
echo "  ssh-copy-id ansible@$(hostname -I | awk '{print $1}')"
