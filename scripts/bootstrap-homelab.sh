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

BACKUP_PATH="/media/sf_E_DRIVE/vaultwarden_backup" # Backup location

# Detect hostname and IP for SSL certificate
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
HOST_IP=$(hostname -I | awk '{print $1}')

# Step 1: Update system packages (if needed)
echo "Checking for package updates..."
apt update && apt upgrade -y

# Step 2: Install required packages (if not installed)
REQUIRED_PACKAGES=("docker.io" "docker-compose" "ufw" "git" "openssh-server" "openssl")
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if ! dpkg -l | grep -qw "$pkg"; then
    echo "Installing $pkg..."
    apt install -y "$pkg"
  else
    echo "$pkg is already installed. Skipping."
  fi
done

# Step 3: Enable & start SSH if not running
if ! systemctl is-active --quiet ssh; then
  echo "Starting SSH service..."
  systemctl enable ssh
  systemctl start ssh
else
  echo "SSH service is already running."
fi

# Step 4: Configure UFW (skip if already configured)
if ! ufw status | grep -q "OpenSSH"; then
  echo "Configuring firewall for SSH..."
  ufw allow OpenSSH
  ufw enable
else
  echo "Firewall already configured. Skipping."
fi

# Step 5: Ensure Vaultwarden backup exists before restoring
if [[ ! -d "$BACKUP_PATH/data" ]]; then
  echo "❌ ERROR: Vaultwarden backup not found at $BACKUP_PATH/data"
  echo "Backup is **mandatory**. Please ensure the correct path is available before running this script."
  exit 1
fi

# Step 6: Ensure Vaultwarden directories exist
mkdir -p "$VAULTWARDEN_DATA_DIR"
mkdir -p "$VAULTWARDEN_SSL_DIR"

# Step 7: Restore Vaultwarden data only if not already restored
if [[ -z "$(ls -A $VAULTWARDEN_DATA_DIR 2>/dev/null)" ]]; then
  echo "Restoring Vaultwarden data from $BACKUP_PATH..."
  rsync -av "$BACKUP_PATH/data/" "$VAULTWARDEN_DATA_DIR/"
  echo "✅ Vaultwarden data restored successfully."
else
  echo "Vaultwarden data already exists. Skipping restore."
fi

# Step 8: Generate SSL certificate only if missing
if [[ ! -f "$VAULTWARDEN_CERT" || ! -f "$VAULTWARDEN_KEY" ]]; then
  echo "Generating SSL certificate for:"
  echo "  - CN: $HOSTNAME_FQDN"
  echo "  - SAN: $HOST_IP"

  # Generate OpenSSL config file with SAN
  cat <<EOF >"$VAULTWARDEN_SSL_DIR/openssl.cnf"
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
    -keyout "$VAULTWARDEN_KEY" \
    -out "$VAULTWARDEN_CERT" \
    -config "$VAULTWARDEN_SSL_DIR/openssl.cnf"

  echo "✅ SSL certificate generated at $VAULTWARDEN_SSL_DIR"
else
  echo "SSL certificate already exists. Skipping generation."
fi

# Step 9: Deploy Vaultwarden with Docker Compose (if not already running)
if ! docker ps | grep -q "vaultwarden"; then
  echo "Deploying Vaultwarden..."
  cat <<EOF >"$VAULTWARDEN_DIR/docker-compose.yml"
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
      - ROCKET_TLS={certs="/ssl/vaultwarden.crt",key="/ssl/vaultwarden.key"}
      - ROCKET_PORT=443
      - ROCKET_ADDRESS=0.0.0.0
EOF

  # Start Vaultwarden
  cd "$VAULTWARDEN_DIR"
  docker-compose up -d
  echo "Vaultwarden is now running. Access it at https://$HOSTNAME_FQDN or https://$HOST_IP"
else
  echo "Vaultwarden is already running. Skipping deployment."
fi

# Step 10: Install the Bitwarden CLI
echo "Installing Bitwarden CLI..."
apt install -y jq curl
BW_CLI_URL="https://vaultwarden.net/download/bitwarden-cli/latest/linux64"
curl -fsSL "$BW_CLI_URL" -o /usr/local/bin/bw
chmod +x /usr/local/bin/bw
echo "✅ Bitwarden CLI installed."

# Step 11: Create ansible user (if it doesn't exist)
if ! id "$ANSIBLE_USER" &>/dev/null; then
  echo "Creating ansible user..."
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
  echo "Ansible user already exists. Skipping."
fi

# Final Output
echo "✅ Homelab bootstrap process completed!"
echo "Vaultwarden: https://$HOSTNAME_FQDN or https://$HOST_IP"
echo "Copy SSH key to your workstation: ssh-copy-id $ANSIBLE_USER@$HOST_IP"
