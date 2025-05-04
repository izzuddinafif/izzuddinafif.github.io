#!/bin/bash

# Variables
NEW_USER="fabricadmin"
GO_VERSION="1.23.1"
FABRIC_VERSION="2.5.10"
CA_VERSION="1.5.13"
SSH_KEYS_URL="https://github.com/izzuddinafif.keys"
LOG_FILE="/var/log/init-ubuntu-20.log"
BIN_DIR="/home/$NEW_USER/bin"                  # Directory for Fabric binaries
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh"
DOCKER_COMPOSE_VERSION="v2.32.0"               # Docker Compose version to install
export DEBIAN_FRONTEND=noninteractive

# Start logging
exec > >(tee -i "$LOG_FILE")
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
apt install -y curl wget git unzip jq build-essential apt-transport-https \
    ca-certificates software-properties-common sshpass tree || { echo "Package installation failed"; exit 1; }

# Install Docker
echo "Installing Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { echo "Failed to import Docker GPG key"; exit 1; }
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt update && apt install -y docker-ce docker-ce-cli containerd.io || { echo "Docker installation failed"; exit 1; }
docker version || { echo "Docker installation verification failed"; exit 1; }

# Create a new user WITHOUT setting a password, and add to Docker group
echo "Creating new user '$NEW_USER'..."
useradd -m -s /bin/bash "$NEW_USER"
usermod -aG docker "$NEW_USER"
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$NEW_USER"
chmod 0440 /etc/sudoers.d/"$NEW_USER"

# Add SSH keys
echo "Adding SSH keys for user '$NEW_USER'..."
mkdir -p /home/"$NEW_USER"/.ssh
if ! curl -sL "$SSH_KEYS_URL" -o /home/"$NEW_USER"/.ssh/authorized_keys; then
    echo "Failed to fetch SSH keys" >&2
    exit 1
fi
chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh
chmod 700 /home/"$NEW_USER"/.ssh
chmod 600 /home/"$NEW_USER"/.ssh/authorized_keys

# Disable root password login for SSH (optional for security)
echo "Disabling root password login for SSH..."
sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload sshd

# Install Docker Compose as a CLI Plugin for the new user
echo "Installing Docker Compose as a CLI plugin for user '$NEW_USER'..."
DOCKER_CONFIG="/home/$NEW_USER/.docker"
mkdir -p "$DOCKER_CONFIG/cli-plugins"
curl -SL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
chown -R "$NEW_USER":"$NEW_USER" "$DOCKER_CONFIG"

# Install Go
echo "Installing Go..."
wget https://golang.org/dl/go"$GO_VERSION".linux-amd64.tar.gz || { echo "Failed to download Go"; exit 1; }
tar -C /usr/local -xzf go"$GO_VERSION".linux-amd64.tar.gz
rm -f go"$GO_VERSION".linux-amd64.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
source /etc/profile
echo "export PATH=\$PATH:/usr/local/go/bin" >> /home/"$NEW_USER"/.bashrc
chown "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.bashrc

# Verify Go installation
echo "Verifying Go installation..."
su - "$NEW_USER" -c "source ~/.bashrc && go version" || { echo "Go installation verification failed"; exit 1; }

# Prepare the target directory for Fabric binaries
echo "Preparing target directory for Fabric binaries..."
mkdir -p "$BIN_DIR"
chown "$NEW_USER":"$NEW_USER" "$BIN_DIR"

# Download the install-fabric.sh script as fabricadmin
echo "Downloading the Hyperledger Fabric install script..."
su - "$NEW_USER" -c "curl -sSLO ${INSTALL_SCRIPT_URL} && chmod +x install-fabric.sh"

# Download and install Fabric binaries and Docker images using specific versions
echo "Installing Hyperledger Fabric binaries and Docker images..."
su - "$NEW_USER" -c "bash install-fabric.sh --fabric-version $FABRIC_VERSION --ca-version $CA_VERSION binary docker" || { echo "Fabric installation failed"; exit 1; }

# Ensure that install-fabric.sh installed binaries into BIN_DIR
echo "Verifying Fabric binaries installation..."
if [ -d "/home/$NEW_USER/fabric-samples/bin" ]; then
    echo "Moving Fabric binaries to $BIN_DIR..."
    su - "$NEW_USER" -c "mv /home/$NEW_USER/fabric-samples/bin/* $BIN_DIR/" || { echo "Failed to move Fabric binaries"; exit 1; }
fi

# Add Fabric binaries to PATH
echo "Exporting Fabric binaries to PATH..."
echo "export PATH=\$PATH:$BIN_DIR" >> /home/"$NEW_USER"/.bashrc
chown "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.bashrc

# Reload the .bashrc for the new user
su - "$NEW_USER" -c "source ~/.bashrc"

# Verify installations
echo "Verifying installations..."
docker --version || echo "Docker installation verification failed"
su - "$NEW_USER" -c "docker compose version" || echo "Docker Compose installation verification failed"
go version || echo "Go installation verification failed"
if [ -f "$BIN_DIR/peer" ]; then
    "$BIN_DIR/peer" version || echo "Fabric peer CLI verification failed"
else
    echo "Fabric peer CLI not found in $BIN_DIR"
fi

echo "=== Hyperledger Fabric setup completed successfully at $(date) ==="
echo "User '$NEW_USER' created WITHOUT a password. Set it later with 'passwd $NEW_USER' after login."
