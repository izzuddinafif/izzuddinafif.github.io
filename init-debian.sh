#!/bin/bash

# Variables
NEW_USER="fabricadmin"
GO_VERSION="1.23.1"
FABRIC_VERSION="2.4.0"
SSH_KEYS_URL="https://github.com/izzuddinafif.keys"
export DEBIAN_FRONTEND=noninteractive

# Update and Install necessary packages
apt update && apt upgrade -y
apt install -y curl wget git unzip jq build-essential apt-transport-https ca-certificates software-properties-common sshpass || { echo "Package installation failed"; exit 1; }

# Install Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - || { echo "Failed to import Docker GPG key"; exit 1; }
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt update && apt install -y docker-ce docker-ce-cli containerd.io

# Create a new user WITHOUT setting a password, and add to Docker group
useradd -m -s /bin/bash "$NEW_USER"
usermod -aG docker "$NEW_USER"
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER

# Add SSH keys
mkdir -p /home/$NEW_USER/.ssh
if ! curl -sL $SSH_KEYS_URL -o /home/$NEW_USER/.ssh/authorized_keys; then
    echo "Failed to fetch SSH keys" >&2
    exit 1
fi
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys

# Disable root password login for SSH (optional for security)
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload sshd

# Install Go
wget https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz || { echo "Failed to download Go"; exit 1; }
tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
rm -f go$GO_VERSION.linux-amd64.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
source /etc/profile

# Install Hyperledger Fabric binaries
if ! su - $NEW_USER -c "curl -sSL https://bit.ly/2ysbOFE | bash -s -- $FABRIC_VERSION"; then
    echo "Failed to install Hyperledger Fabric binaries" >&2
    exit 1
fi

# Verify installations
docker --version
go version
su - $NEW_USER -c "peer version" || echo "Fabric peer CLI not found"

echo "Unattended setup completed successfully!"
echo "User '$NEW_USER' created WITHOUT a password. Set it later with 'passwd $NEW_USER' after login."
