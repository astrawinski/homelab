#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

SSH_USER="subnet"
SSH_DIR="/home/$SSH_USER/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
LOCAL_SSH_KEY="$HOME/.ssh/id_ed25519.pub"

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

# Automatically copy SSH key from local machine
echo "Copying SSH key from local machine..."
if ssh-copy-id -i "$LOCAL_SSH_KEY" "$SSH_USER@$(hostname -I | awk '{print $1}')"; then
    echo "✅ SSH key successfully copied!"
else
    echo "⚠️ Failed to copy SSH key. Please run the following command manually:"
    echo "ssh-copy-id $SSH_USER@$(hostname -I | awk '{print $1}')"
    exit 1
fi

# Ask if user wants to disable password authentication
read -p "Do you want to disable password authentication for SSH? (y/n): " CONFIRM
if [[ "$CONFIRM" == "y" ]]; then
    echo "Disabling password authentication..."
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    # Restart SSH service to apply changes
    systemctl restart ssh
    echo "✅ Password authentication has been disabled. Only SSH key authentication is allowed now."
else
    echo "⚠️ Password authentication is still enabled. You can disable it later by running:"
    echo "    sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
    echo "    sudo systemctl restart ssh"
fi

echo "✅ SSH setup complete. You can now connect remotely using SSH keys."
echo "To test: ssh $SSH_USER@$(hostname -I | awk '{print $1}')"
