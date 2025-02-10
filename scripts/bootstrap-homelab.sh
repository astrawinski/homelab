#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

ANSIBLE_USER="ansible"
ANSIBLE_DIR="/home/$ANSIBLE_USER/.ssh"
AUTHORIZED_KEYS="$ANSIBLE_DIR/authorized_keys"
DEFAULT_PASSWORD="ChangeMeNow!"

# Create the ansible user if it doesn't exist
echo "Creating ansible user..."
if ! id "$ANSIBLE_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$ANSIBLE_USER"
    echo "$ANSIBLE_USER:$DEFAULT_PASSWORD" | chpasswd
    passwd --expire "$ANSIBLE_USER"
    echo "User $ANSIBLE_USER created with temporary password: $DEFAULT_PASSWORD"
else
    echo "User $ANSIBLE_USER already exists."
fi

# Update package list
echo "Updating package list..."
apt update -y

# Install OpenSSH Server
echo "Installing OpenSSH Server..."
apt install -y openssh-server

# Enable and start SSH service
echo "Enabling and starting SSH service..."
systemctl enable ssh
systemctl start ssh

# Allow SSH through the firewall
echo "Allowing SSH through the firewall..."
ufw allow OpenSSH
ufw enable

# Ensure SSH directory exists and set correct permissions
echo "Configuring SSH directory and permissions..."
mkdir -p "$ANSIBLE_DIR"
chmod 700 "$ANSIBLE_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown -R $ANSIBLE_USER:$ANSIBLE_USER "$ANSIBLE_DIR"

# Enable passwordless sudo
echo "Enabling passwordless sudo for $ANSIBLE_USER..."
echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/$ANSIBLE_USER
chmod 0440 /etc/sudoers.d/$ANSIBLE_USER

# Detect if running inside VirtualBox
if dmidecode -s system-product-name | grep -qi "VirtualBox"; then
    echo "Running inside a VirtualBox VM. Installing Guest Additions..."
    apt install -y virtualbox-guest-utils virtualbox-guest-x11
    echo "VirtualBox Guest Additions installed."
else
    echo "Not running inside a VirtualBox VM. Skipping Guest Additions installation."
fi

echo "✅ SSH is now enabled, and passwordless sudo is configured for $ANSIBLE_USER."
echo ""
echo "Temporary password for $ANSIBLE_USER: $DEFAULT_PASSWORD"
echo "It must be changed on first login."
echo ""
echo "From your remote machine, login with ssh:"
echo "    ssh $ANSIBLE_USER@$(hostname -I | awk '{print $1}')"
echo "And change your password."
echo ""
echo "Next, from your remote machine, copy your SSH key using:"
echo "    ssh-copy-id $ANSIBLE_USER@$(hostname -I | awk '{print $1}')"
echo ""
echo "Once done, run the 'secure-ssh.sh' script to disable password login."
