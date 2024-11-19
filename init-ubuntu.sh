#!/bin/bash

# Script to initialize an Ubuntu server with essential tools and create a user.

# Exit on any error
set -e

# Prompt for username and password
read -p "Enter the username to create: " USERNAME
if [[ -z "$USERNAME" ]]; then
    echo "Error: Username cannot be empty."
    exit 1
fi

read -sp "Enter the password for user '$USERNAME': " PASSWORD
echo
if [[ -z "$PASSWORD" ]]; then
    echo "Error: Password cannot be empty."
    exit 1
fi

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt update -y && sudo apt upgrade -y

# Install commonly used tools
echo "Installing essential tools..."
sudo apt install -y curl wget git vim htop unzip build-essential net-tools ufw software-properties-common tldr

# Create a new user
echo "Creating a new user: $USERNAME..."
sudo useradd -m -s /bin/bash -G sudo "$USERNAME"
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Add user to the sudo group
echo "Adding $USERNAME to the sudo group..."
sudo usermod -aG sudo "$USERNAME"

# Enable TLDR command with auto-update
echo "Initializing TLDR cheat sheets..."
tldr --update

# Set up basic firewall (optional)
echo "Setting up a basic firewall..."
sudo ufw allow OpenSSH
sudo ufw enable

# Completion message
echo "Initialization script completed successfully!"
echo "User '$USERNAME' has been created and added to the sudo group."
