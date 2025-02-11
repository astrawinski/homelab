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

# Detect if running inside VirtualBox
if dmidecode -s system-product-name | grep -qi "VirtualBox"; then
    echo "Running inside a VirtualBox VM. Ensuring shared folder access..."

    # Ensure vboxsf group exists
    if ! getent group vboxsf >/dev/null; then
        groupadd vboxsf
        echo "Created vboxsf group."
    fi

    # Add the current user to vboxsf group
    CURRENT_USER=$(logname)
    if id "$CURRENT_USER" | grep -q "vboxsf"; then
        echo "User $CURRENT_USER is already in vboxsf group."
    else
        usermod -aG vboxsf "$CURRENT_USER"
        echo "Added $CURRENT_USER to vboxsf group."
    fi

    # Apply group changes immediately to the current terminal session
    newgrp vboxsf <<EOF
    echo "Group permissions applied immediately for $CURRENT_USER."
EOF
else
    echo "Not running inside a VirtualBox VM. Skipping vboxsf setup."
fi

# Ensure /opt/vaultwarden exists
mkdir -p /opt/vaultwarden/data
mkdir -p /opt/vaultwarden/ssl

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

# Detect hostname and IP for SSL certificate
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
HOST_IP=$(hostname -I | awk '{print $1}')

echo "Generating SSL certificate for:"
echo "  - CN: $HOSTNAME_FQDN"
echo "  - SAN: $HOST_IP"

# Generate OpenSSL config file with SAN
cat <<EOF > /opt/vaultwarden/ssl/openssl.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $HOSTNAME_FQDN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $HOSTNAME_FQDN
IP.1 = $HOST_IP
EOF

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/vaultwarden/ssl/vaultwarden.key \
    -out /opt/vaultwarden/ssl/vaultwarden.crt \
    -config /opt/vaultwarden/ssl/openssl.cnf

echo "✅ SSL certificate generated at /opt/vaultwarden/ssl/"

# Deploy Vaultwarden with Docker Compose (now using HTTPS)
echo "Deploying Vaultwarden..."
cat <<EOF > /opt/vaultwarden/docker-compose.yml
version: '3'
services:
  vaultwarden:
    image: bitwardenrs/server:latest
    restart: unless-stopped
    volumes:
      - /opt/vaultwarden/data:/data
      - /opt/vaultwarden/ssl:/ssl
    ports:
      - "443:443"
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
      - ROCKET_TLS={certs="/ssl/vaultwarden.crt",key="/ssl/vaultwarden.key"}
EOF

# Start Vaultwarden
cd /opt/vaultwarden
docker-compose up -d

echo "Vaultwarden is now running. Access it at https://$HOSTNAME_FQDN or https://$HOST_IP"

# Generate SSH key for ansible user
echo "Creating ansible user and SSH key..."
useradd -m -s /bin/bash ansible
mkdir -p /home/ansible/.ssh
ssh-keygen -t ed25519 -f /home/ansible/.ssh/id_ed25519 -N ""
chown -R ansible:ansible /home/ansible/.ssh

echo "Done! Now copy the SSH key to your workstation:"
echo "  ssh-copy-id ansible@$HOST_IP"
