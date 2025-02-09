#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

SSH_USER="subnet"
SSH_DIR="/home/$SSH_USER/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

echo "Updating package list..."
apt update -y

echo "Installing OpenSSH Server..."
apt install -y openssh-server

echo "Enabling and starting SSH service..."
systemctl enable ssh
systemctl start ssh

echo "Allowing SSH through the firewall..."
ufw allow OpenSSH
ufw enable

# Ensure SSH directory exists and set correct permissions
echo "Configuring SSH directory and permissions..."
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown -R $SSH_USER:$SSH_USER "$SSH_DIR"

echo "✅ SSH is now enabled and ready for key authentication."
echo ""
echo "Next, from your remote machine, copy your SSH key using:"
echo "    ssh-copy-id $SSH_USER@$(hostname -I | awk '{print $1}')"
echo ""
echo "Once done, run the 'secure-ssh.sh' script to disable password login."
