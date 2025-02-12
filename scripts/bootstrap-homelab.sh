#!/bin/bash
set -e # Exit immediately on error

# Ensure we are running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

# Variables
ANSIBLE_USER="ansible"
ANSIBLE_DIR="/home/$ANSIBLE_USER/.ssh"
ANSIBLE_TMP_PASS="ChangeMeNow!"

VAULTWARDEN_DIR="/opt/vaultwarden"
VAULTWARDEN_DATA_DIR="$VAULTWARDEN_DIR/data"
VAULTWARDEN_SSL_DIR="$VAULTWARDEN_DIR/ssl"
VAULTWARDEN_CERT="$VAULTWARDEN_SSL_DIR/vaultwarden.crt"
VAULTWARDEN_KEY="$VAULTWARDEN_SSL_DIR/vaultwarden.key"

BACKUP_PATH="/media/sf_E_DRIVE/vaultwarden_backup"  # Set your backup location

# Detect hostname and IP for SSL certificate
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
HOST_IP=$(hostname -I | awk '{print $1}')

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

# Ensure the Vaultwarden backup exists
if [[ ! -d "$BACKUP_PATH/data" ]]; then
  echo "❌ ERROR: Vaultwarden backup not found at $BACKUP_PATH/data"
  echo "Backup is **mandatory**. Please ensure the correct path is available before running this script."
  exit 1
fi

# Ensure Vaultwarden directories exist
mkdir -p "$VAULTWARDEN_DATA_DIR"
mkdir -p "$VAULTWARDEN_SSL_DIR"

# Restore Vaultwarden data
echo "Restoring Vaultwarden data from $BACKUP_PATH..."
rsync -av "$BACKUP_PATH/data/" "$VAULTWARDEN_DATA_DIR/"
echo "✅ Vaultwarden data restored successfully."

# Generate SSL certificate for:
echo "Generating SSL certificate for:"
echo "  - CN: $HOSTNAME_FQDN"
echo "  - SAN: $HOST_IP"

# Generate OpenSSL config file with SAN
cat <<EOF >$VAULTWARDEN_SSL_DIR/openssl.cnf
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
  -keyout $VAULTWARDEN_KEY \
  -out $VAULTWARDEN_CERT \
  -config $VAULTWARDEN_SSL_DIR/openssl.cnf

echo "✅ SSL certificate generated at $VAULTWARDEN_SSL_DIR"

# Deploy Vaultwarden with Docker Compose (now using HTTPS)
echo "Deploying Vaultwarden..."
cat <<EOF >$VAULTWARDEN_DIR/docker-compose.yml
version: '3'
services:
  vaultwarden:
    image: bitwardenrs/server:latest
    restart: unless-stopped
    volumes:
      - $VAULTWARDEN_DATA_DIR:/data
      - $VAULTWARDEN_SSL_DIR:/ssl
    ports:
      - "443:443"
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=true
      - ROCKET_TLS={certs="$VAULTWARDEN_CERT",key="$VAULTWARDEN_KEY"}
      - ROCKET_PORT=443
      - ROCKET_ADDRESS=0.0.0.0
EOF

# Start Vaultwarden
cd "$VAULTWARDEN_DIR"
docker-compose up -d

echo "Vaultwarden is now running. Access it at https://$HOSTNAME_FQDN or https://$HOST_IP"

# Create ansible user
echo "Creating ansible user..."
if ! id "$ANSIBLE_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$ANSIBLE_USER"
  echo "$ANSIBLE_USER:$ANSIBLE_TMP_PASS" | chpasswd
  passwd --expire "$ANSIBLE_USER"
  mkdir -p "$ANSIBLE_DIR"
  ssh-keygen -t ed25519 -f "$ANSIBLE_DIR/id_ed25519" -N ""
  chown -R $ANSIBLE_USER:$ANSIBLE_USER "$ANSIBLE_DIR"
  echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/$ANSIBLE_USER
  chmod 0440 /etc/sudoers.d/$ANSIBLE_USER
  echo "User $ANSIBLE_USER created with temporary password: $ANSIBLE_TMP_PASS"
else
  echo "User $ANSIBLE_USER already exists."
fi

echo "Done! Now copy the SSH key to your workstation:"
echo "  ssh-copy-id $ANSIBLE_USER@$HOST_IP"
