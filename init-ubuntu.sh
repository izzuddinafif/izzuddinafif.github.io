#!/bin/bash

# Exit on any error
set -e

# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root. Please run with sudo or as root user."
    exit 1
fi

PUBLIC_IP=$(curl -s https://ifconfig.me) # Get the server's public IP
EMAIL="izzuddinafif@gmail.com"
TIMEZONE="Asia/Jakarta"
USER="afif"

# Update and upgrade the system
echo "Updating and upgrading the system..."
DEBIAN_FRONTEND=noninteractive apt update -y && apt upgrade -y
apt autoremove -y
apt clean

# Install essential tools
echo "Installing essential tools..."
DEBIAN_FRONTEND=noninteractive apt install -y curl wget git vim htop unzip build-essential net-tools ufw software-properties-common tldr neofetch tmux fail2ban rkhunter clamav sysstat glances ncdu lvm2 \
unattended-upgrades ntp logwatch rsync tree certbot python3-certbot-nginx docker.io golang containerd nodejs python3 python3-pip python3-venv nmap tcpdump iptraf-ng iperf3 npm

# Install modern utilities
echo "Installing modern utilities..."
DEBIAN_FRONTEND=noninteractive apt install -y ripgrep bat fzf zoxide fd-find

# Install Nerd Font
FONT_NAME="Hack"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_NAME}.zip"
echo "Installing Nerd Font ($FONT_NAME)..."
mkdir -p /usr/share/fonts/truetype/${FONT_NAME,,}
wget -q $FONT_URL -O /tmp/${FONT_NAME}.zip
unzip -oq /tmp/${FONT_NAME}.zip -d /usr/share/fonts/truetype/${FONT_NAME,,}
fc-cache -fv
if fc-list | grep -qi "$FONT_NAME Nerd Font"; then
    echo "$FONT_NAME Nerd Font installed successfully."
else
    echo "Error: $FONT_NAME Nerd Font installation failed."
    exit 1
fi

# Configure locale and timezone
echo "Configuring locale and timezone..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
timedatectl set-timezone $TIMEZONE

# Enable automatic security updates
echo "Enabling automatic security updates..."
dpkg-reconfigure -plow unattended-upgrades

# Configure UFW firewall
echo "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable
ufw logging on

# Secure SSH
echo "Securing SSH configuration..."
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "AllowUsers $USER" >> /etc/ssh/sshd_config
systemctl restart sshd

# Set up SSH key-based authentication
echo "Setting up SSH key-based authentication..."
mkdir -p /home/$USER/.ssh
echo "getting public SSH key for $USER..."
curl https://github.com/$USER.keys >> /home/$USER/.ssh/authorized_keys
chown -R $USER:$USER /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/authorized_keys

# Configure Fail2Ban
echo "Installing and configuring Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Configure Logwatch
echo "Setting up Logwatch..."
echo "/usr/sbin/logwatch --output mail --mailto $EMAIL --detail high" > /etc/cron.daily/00logwatch
chmod +x /etc/cron.daily/00logwatch

# Set up dynamic swap space
echo "Setting up dynamic swap space..."
SWAP_SIZE=$(awk '/MemTotal/ {print int($2/1024*2)}' /proc/meminfo)M
fallocate -l $SWAP_SIZE /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Install and configure Docker
echo "Installing and configuring Docker..."
systemctl enable docker
systemctl start docker

# Add user to the Docker group
echo "Adding $USER to the Docker group..."
groupadd docker || true
usermod -aG docker $USER
newgrp docker <<EONG
  echo "User $USER has been added to the docker group. Log out and back in to apply the changes."
EONG

# Install and configure Node.js
echo "Setting up Node.js..."
npm install -g npm@latest
npm install -g yarn pm2

# Completion message
echo "Setup Summary:"
echo "- Public IP: $PUBLIC_IP"
echo "- Email for Logwatch: $EMAIL"
echo "- Timezone: $TIMEZONE"
echo "- Essential tools and utilities installed."
echo "- Firewall (UFW) configured and enabled."
echo "- Swap space: $(free -h | grep Swap | awk '{print $2}')"
echo "Initialization script completed successfully!"
