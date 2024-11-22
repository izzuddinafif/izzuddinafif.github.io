#!/bin/bash

# Exit on any error
set -e

# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root. Please run with sudo or as root user."
    exit 1
fi

# Check if username is provided as a parameter
if [[ -z "$1" ]]; then
    echo "Usage: $0 <username>"
    exit 1
fi

PUBLIC_IP=$(curl -s https://ifconfig.me) # Get the server's public IP
USERNAME=$1
EMAIL="izzuddinafif@gmail.com"
TIMEZONE="Asia/Jakarta"

# Update and upgrade the system
echo "Updating and upgrading the system..."
DEBIAN_FRONTEND=noninteractive apt update -y && apt upgrade -y
apt autoremove -y
apt clean

# Install essential tools
echo "Installing essential tools..."
DEBIAN_FRONTEND=noninteractive apt install -y curl wget git vim htop unzip build-essential net-tools ufw software-properties-common tldr neofetch tmux fail2ban rkhunter clamav sysstat glances ncdu lvm2 \
unattended-upgrades ntp logwatch rsync tree certbot python3-certbot-nginx docker.io golang containerd nodejs python3 python3-pip python3-venv nmap tcpdump iptraf-ng iperf3 npm

# Install modern and fast utilities
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

# Create a new user and add to sudo group
echo "Creating a new user: $USERNAME..."
adduser "$USERNAME"
usermod -aG sudo "$USERNAME"

# Set up Zsh and Oh-My-Zsh
echo "Installing Zsh and configuring Oh-My-Zsh..."
DEBIAN_FRONTEND=noninteractive apt install -y zsh
chsh -s $(which zsh) $USERNAME

sudo -u $USERNAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Zsh plugins and Powerlevel10k theme
echo "Installing Zsh plugins and Powerlevel10k theme..."
ZSH_CUSTOM="/home/$USERNAME/.oh-my-zsh/custom"
sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
sudo -u $USERNAME git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

# Configure Zsh
echo "Configuring Zsh..."
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' /home/$USERNAME/.zshrc
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' /home/$USERNAME/.zshrc
chown -R $USERNAME:$USERNAME /home/$USERNAME/.oh-my-zsh

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
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config
systemctl restart sshd

# Set up SSH key-based authentication
echo "Setting up SSH key-based authentication..."
mkdir -p /home/$USERNAME/.ssh
echo "Paste your public SSH key for $USERNAME:"
read -r PUBKEY
echo "$PUBKEY" > /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

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

# Install and configure Netdata
echo "Installing Netdata for system monitoring..."
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
sed -i 's/bind to = .*/bind to = 127.0.0.1/' /etc/netdata/netdata.conf
systemctl restart netdata

# Completion message
echo "Setup Summary:"
echo "- User created: $USERNAME"
echo "- Email for Logwatch: $EMAIL"
echo "- Timezone: $TIMEZONE"
echo "- Essential tools and utilities installed."
echo "- Firewall (UFW) configured and enabled."
echo "- SSH hardened with key-based authentication."
echo "- Swap space: $(free -h | grep Swap | awk '{print $2}')"
echo "  Access Netdata via SSH port-forwarding:"
echo "  ssh -i /path/to/your/private-key -L 19999:127.0.0.1:19999 $USERNAME@$PUBLIC_IP"
echo "Initialization script completed successfully!"
