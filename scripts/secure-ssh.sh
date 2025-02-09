#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

SSH_USER="ansible"
AUTHORIZED_KEYS="/home/$SSH_USER/.ssh/authorized_keys"

# Ensure SSH key exists
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    echo "ERROR: No SSH key found for $SSH_USER. Please copy your key first using:"
    echo "ssh-copy-id $SSH_USER@$(hostname -I | awk '{print $1}')"
    exit 1
fi

# Disable password authentication
echo "Disabling password authentication..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH
echo "Restarting SSH service..."
systemctl restart ssh

echo "✅ SSH key authentication enforced. Password login is now disabled."
