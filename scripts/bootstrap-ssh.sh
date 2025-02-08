#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

# Variables (Edit if needed)
SSH_USER="subnet"
AUTHORIZED_KEYS="/home/$SSH_USER/.ssh/authorized_keys"
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

# Ensure SSH directory exists
echo "Configuring SSH key authentication..."
mkdir -p /home/$SSH_USER/.ssh
chmod 700 /home/$SSH_USER/.ssh

# Copy the SSH public key from the local machine (ensure this exists)
if [ -f "$LOCAL_SSH_KEY" ]; then
    cat "$LOCAL_SSH_KEY" >> "$AUTHORIZED_KEYS"
    echo "Added SSH key to authorized_keys."
else
    echo "ERROR: No SSH key found at $LOCAL_SSH_KEY. Please generate one using:"
    echo "ssh-keygen -t ed25519 -C 'ansible@homelab'"
    exit 1
fi

# Set correct permissions
chown -R $SSH_USER:$SSH_USER /home/$SSH_USER/.ssh
chmod 600 "$AUTHORIZED_KEYS"

# Disable password authentication for SSH
echo "Disabling password authentication..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH to apply changes
echo "Restarting SSH service..."
systemctl restart ssh

echo "✅ SSH setup complete. You can now connect remotely using SSH keys."
echo "To test: ssh $SSH_USER@$(hostname -I | awk '{print $1}')"
