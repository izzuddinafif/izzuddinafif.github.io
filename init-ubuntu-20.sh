#!/bin/bash

# Variables
NEW_USER="fabricadmin"
GO_VERSION="1.23.1"
FABRIC_VERSION="2.5.10"
CA_VERSION="1.5.13"
SSH_KEYS_URL="https://github.com/izzuddinafif.keys"
BIN_DIR="/home/$NEW_USER/bin"
LOG_FILE="/var/log/init-ubuntu-20.log"
export DEBIAN_FRONTEND=noninteractive

# Start logging
exec > >(tee -i $LOG_FILE)
exec 2>&1

echo "=== Starting Hyperledger Fabric setup at $(date) ==="

# Ensure the script runs on Ubuntu 20.04
if [ "$(lsb_release -rs)" != "20.04" ]; then
    echo "This script is designed for Ubuntu 20.04. Please use the correct OS."
    exit 1
fi

# Update and Install necessary packages
echo "Updating and installing necessary packages..."
apt update && apt upgrade -y
apt install -y curl wget git unzip jq build-essential apt-transport-https ca-certificates software-properties-common sshpass || { echo "Package installation failed"; exit 1; }

# Install Docker
echo "Installing Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { echo "Failed to import Docker GPG key"; exit 1; }
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt update && apt install -y docker-ce docker-ce-cli containerd.io
docker version || { echo "Docker installation verification failed"; exit 1; }

# Install Docker Compose v2.x
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version || { echo "Docker Compose installation verification failed"; exit 1; }

# Create a new user WITHOUT setting a password, and add to Docker group
echo "Creating new user '$NEW_USER'..."
useradd -m -s /bin/bash "$NEW_USER"
usermod -aG docker "$NEW_USER"
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER

# Add SSH keys
echo "Adding SSH keys for user '$NEW_USER'..."
mkdir -p /home/$NEW_USER/.ssh
if ! curl -sL $SSH_KEYS_URL -o /home/$NEW_USER/.ssh/authorized_keys; then
    echo "Failed to fetch SSH keys" >&2
    exit 1
fi
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys

# Disable root password login for SSH (optional for security)
echo "Disabling root password login for SSH..."
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload sshd

# Install Go
echo "Installing Go..."
wget https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz || { echo "Failed to download Go"; exit 1; }
tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
rm -f go$GO_VERSION.linux-amd64.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
echo "export PATH=\$PATH:/usr/local/go/bin" >> /home/$NEW_USER/.bashrc
su - $NEW_USER -c "source /home/$NEW_USER/.bashrc"
go version || { echo "Go installation verification failed"; exit 1; }

# Prepare the target directory for Fabric binaries
echo "Preparing target directory for Fabric binaries..."
mkdir -p $BIN_DIR
chown -R $NEW_USER:$NEW_USER $BIN_DIR

# Download the install-fabric.sh script as fabricadmin
echo "Downloading the Hyperledger Fabric install script..."
su - $NEW_USER -c "curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh"

# Install Fabric binaries and Docker images using specific versions
echo "Installing Hyperledger Fabric binaries and Docker images..."
su - $NEW_USER -c "bash install-fabric.sh --fabric-version $FABRIC_VERSION --ca-version $CA_VERSION -d $BIN_DIR binary docker"

# Add Fabric binaries to PATH
echo "Exporting Fabric binaries to PATH..."
echo "export PATH=\$PATH:$BIN_DIR" >> /home/$NEW_USER/.bashrc
su - $NEW_USER -c "source /home/$NEW_USER/.bashrc"

# Verify installations
echo "Verifying installations..."
docker --version || echo "Docker installation verification failed"
docker-compose version || echo "Docker Compose installation verification failed"
go version || echo "Go installation verification failed"
su - $NEW_USER -c "$BIN_DIR/peer version" || echo "Fabric peer CLI not found"

echo "=== Hyperledger Fabric setup completed successfully at $(date) ==="
echo "User '$NEW_USER' created WITHOUT a password. Set it later with 'passwd $NEW_USER' after login."
