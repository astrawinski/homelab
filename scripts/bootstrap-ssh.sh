#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

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

echo "✅ SSH is now enabled. You can connect remotely."
echo "Next, from your workstation, copy your SSH key:"
echo ""
echo "    ssh-copy-id subnet@$(hostname -I | awk '{print $1}')"
echo ""
echo "Once done, run the second script to enforce key authentication."
