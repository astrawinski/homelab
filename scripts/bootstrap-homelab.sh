#!/bin/bash
set -e # Exit immediately on error

# Ensure we are running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

# Variables
VAULTWARDEN_DIR="/opt/vaultwarden"
VAULTWARDEN_DATA_DIR="$VAULTWARDEN_DIR/data"
VAULTWARDEN_SSL_DIR="$VAULTWARDEN_DIR/ssl"
VAULTWARDEN_CERT="$VAULTWARDEN_SSL_DIR/vaultwarden.crt"
VAULTWARDEN_KEY="$VAULTWARDEN_SSL_DIR/vaultwarden.key"

BACKUP_PATH="/media/sf_E_DRIVE/vaultwarden_backup" # Backup location
BW_CLI_PATH="/usr/local/bin/bw"
BW_CONFIG_DIR="/root/.config/Bitwarden CLI"

# Detect hostname and IP for SSL certificate
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
HOST_IP=$(hostname -I | awk '{print $1}')

# Updates system packages
doc_update_system() {
  echo "Checking for package updates..."
  apt update && apt upgrade -y
}

# Installs required packages if they are not already installed
doc_install_packages() {
  REQUIRED_PACKAGES=("docker.io" "docker-compose" "ufw" "git" "openssh-server" "openssl" "curl" "unzip")
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -qw "$pkg"; then
      echo "Installing $pkg..."
      apt install -y "$pkg"
    else
      echo "$pkg is already installed. Skipping."
    fi
  done
}

# Configures and starts the SSH service if it is not running
doc_configure_ssh() {
  if ! systemctl is-active --quiet ssh; then
    echo "Starting SSH service..."
    systemctl enable ssh
    systemctl start ssh
  else
    echo "SSH service is already running."
  fi
}

# Configures firewall rules if not already configured
doc_configure_firewall() {
  if ! ufw status | grep -q "OpenSSH"; then
    echo "Configuring firewall for SSH..."
    ufw allow OpenSSH
    ufw enable
  else
    echo "Firewall already configured. Skipping."
  fi
}

# Restores Vaultwarden data from a backup if it does not already exist
doc_restore_vaultwarden() {
  if [[ ! -d "$BACKUP_PATH/data" ]]; then
    echo "❌ ERROR: Vaultwarden backup not found at $BACKUP_PATH/data"
    exit 1
  fi
  mkdir -p "$VAULTWARDEN_DATA_DIR" "$VAULTWARDEN_SSL_DIR"
  if [[ -z "$(ls -A $VAULTWARDEN_DATA_DIR 2>/dev/null)" ]]; then
    echo "Restoring Vaultwarden data from $BACKUP_PATH..."
    rsync -av "$BACKUP_PATH/data/" "$VAULTWARDEN_DATA_DIR/"
    echo "✅ Vaultwarden data restored successfully."
  else
    echo "Vaultwarden data already exists. Skipping restore."
  fi
}

# Generates a self-signed SSL certificate for Vaultwarden if not already present
doc_generate_ssl_certificate() {
  if [[ ! -f "$VAULTWARDEN_CERT" || ! -f "$VAULTWARDEN_KEY" ]]; then
    echo "Generating SSL certificate for: $HOSTNAME_FQDN ($HOST_IP)"
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

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$VAULTWARDEN_KEY" \
      -out "$VAULTWARDEN_CERT" \
      -config "$VAULTWARDEN_SSL_DIR/openssl.cnf"
    echo "✅ SSL certificate generated at $VAULTWARDEN_SSL_DIR"
  else
    echo "SSL certificate already exists. Skipping generation."
  fi
}

# Deploys Vaultwarden using Docker Compose if not already running
doc_deploy_vaultwarden() {
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
    cd "$VAULTWARDEN_DIR"
    docker-compose up -d
    echo "Vaultwarden is now running at https://$HOSTNAME_FQDN or https://$HOST_IP"
  else
    echo "Vaultwarden is already running. Skipping deployment."
  fi
}

# Installs Bitwarden CLI if it is not already installed
doc_install_bw_cli() {
  if [[ ! -f "$BW_CLI_PATH" ]]; then
    echo "Installing Bitwarden CLI..."
    curl -Lso bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"
    unzip -o bw.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/bw
    rm bw.zip
    echo "✅ Bitwarden CLI installed."
  else
    echo "Bitwarden CLI already installed. Skipping."
  fi
}

# Configures Bitwarden CLI for use with Vaultwarden
doc_configure_bw_cli() {
  mkdir -p "$BW_CONFIG_DIR"
  bw config server "https://$HOST_IP"
  cp "$VAULTWARDEN_CERT" /usr/local/share/ca-certificates/
  cp "$VAULTWARDEN_CERT" /usr/share/ca-certificates/
  update-ca-certificates
  cp "$VAULTWARDEN_CERT" "$BW_CONFIG_DIR/"
  echo "NODE_EXTRA_CA_CERTS=$BW_CONFIG_DIR/vaultwarden.crt" | tee -a /etc/environment
  echo "✅ Bitwarden CLI configured for Vaultwarden."
}

# Execute functions
doc_update_system
doc_install_packages
doc_configure_ssh
doc_configure_firewall
doc_restore_vaultwarden
doc_generate_ssl_certificate
doc_deploy_vaultwarden
doc_install_bw_cli
doc_configure_bw_cli

echo "✅ Homelab bootstrap process completed!"
echo "Vaultwarden: https://$HOSTNAME_FQDN or https://$HOST_IP"
