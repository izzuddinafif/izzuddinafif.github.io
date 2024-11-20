#!/bin/bash

# Exit on any error
set -e

# Log everything to a file
LOGFILE="/var/log/init-hlf.log"
exec > >(tee -i "$LOGFILE")
exec 2>&1

# Colors for feedback
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m' # No color

# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Please run with sudo or as root user.${NC}"
    exit 1
fi

# Variables
GO_VERSION="1.23.1"
HLF_VERSION="2.5.0"
HLF_SAMPLES_VERSION="2.5.0"
EXPLORER_VERSION="2.0.0"
FABRIC_CA_CERT_PATH="/etc/hyperledger/fabric-ca/certs"
USERNAME=$(logname) # Get the username of the user who invoked sudo
POSTGRES_PASSWORD=$(openssl rand -base64 12)
EXPLORER_PASSWORD=$(openssl rand -base64 12)

# Function to check the exit status of commands
check_success() {
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: $1 failed. Check the log file: $LOGFILE.${NC}"
        exit 1
    fi
}

# Update and upgrade the system
echo -e "${GREEN}Updating and upgrading the system...${NC}"
DEBIAN_FRONTEND=noninteractive apt update -y && apt upgrade -y
check_success "System update and upgrade"
apt autoremove -y
apt clean

# Install prerequisites
echo -e "${GREEN}Installing prerequisites...${NC}"
DEBIAN_FRONTEND=noninteractive apt install -y curl wget git unzip jq build-essential apt-transport-https ca-certificates software-properties-common python3-certbot-nginx
check_success "Prerequisite installation"

# Install Docker
echo -e "${GREEN}Installing Docker...${NC}"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt update -y
    apt install -y docker-ce docker-ce-cli containerd.io
    check_success "Docker installation"
    systemctl start docker
    systemctl enable docker
else
    echo "Docker is already installed."
fi

# Add user to the Docker group
echo -e "${GREEN}Adding $USERNAME to the Docker group...${NC}"
usermod -aG docker "$USERNAME"

# Install Docker Compose
echo -e "${GREEN}Installing Docker Compose...${NC}"
if ! command -v docker-compose &>/dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    check_success "Docker Compose installation"
else
    echo "Docker Compose is already installed."
fi

# Install PostgreSQL
echo -e "${GREEN}Checking PostgreSQL installation...${NC}"
if ! command -v psql &>/dev/null; then
    echo "PostgreSQL is not installed. Installing PostgreSQL..."
    apt install -y postgresql
    check_success "PostgreSQL installation"
    systemctl start postgresql
    systemctl enable postgresql
    # Configure database for Explorer
    echo "Configuring PostgreSQL for Hyperledger Explorer..."
    sudo -u postgres psql -c "CREATE DATABASE fabricexplorer;"
    sudo -u postgres psql -c "CREATE USER explorer WITH ENCRYPTED PASSWORD '${EXPLORER_PASSWORD}';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE fabricexplorer TO explorer;"
    check_success "PostgreSQL configuration for Hyperledger Explorer"
else
    echo "PostgreSQL is already installed."
fi

# Secure PostgreSQL credentials
echo -e "${GREEN}Saving PostgreSQL credentials securely...${NC}"
echo "PostgreSQL Explorer Password: $EXPLORER_PASSWORD" > /root/explorer_credentials.txt
chmod 600 /root/explorer_credentials.txt

# Install Go
echo -e "${GREEN}Installing Go...${NC}"
if ! command -v go &>/dev/null || [[ "$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')" != "$GO_VERSION" ]]; then
    echo "Installing Go $GO_VERSION..."
    GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
    wget -q "https://golang.org/dl/$GO_TAR" -O /tmp/$GO_TAR
    tar -C /usr/local -xzf /tmp/$GO_TAR
    echo "export PATH=\$PATH:/usr/local/go/bin" >> /home/$USERNAME/.profile
    echo "export GOPATH=\$HOME/go" >> /home/$USERNAME/.profile
    echo "export PATH=\$PATH:\$GOPATH/bin" >> /home/$USERNAME/.profile
    chown "$USERNAME:$USERNAME" /home/$USERNAME/.profile
    check_success "Go installation"
else
    echo "Go $GO_VERSION is already installed."
fi

# Load environment variables
source /home/$USERNAME/.profile

# Clone Hyperledger Fabric samples
echo -e "${GREEN}Cloning Hyperledger Fabric samples...${NC}"
if [[ ! -d /home/$USERNAME/fabric-samples ]]; then
    sudo -u "$USERNAME" git clone -b "release-${HLF_SAMPLES_VERSION}" https://github.com/hyperledger/fabric-samples.git /home/$USERNAME/fabric-samples
    check_success "Hyperledger Fabric samples cloning"
else
    echo "Hyperledger Fabric samples already cloned."
fi

# Dockerized Hyperledger Explorer setup
echo -e "${GREEN}Setting up Hyperledger Explorer with Docker...${NC}"
cat <<EOF > /home/$USERNAME/hyperledger-explorer/docker-compose.yml
version: '3.7'
services:
  explorerdb:
    image: postgres:13
    environment:
      POSTGRES_USER: explorer
      POSTGRES_PASSWORD: ${EXPLORER_PASSWORD}
      POSTGRES_DB: fabricexplorer
    ports:
      - "5432:5432"
    volumes:
      - explorerdb-data:/var/lib/postgresql/data
  explorer:
    image: hyperledger/explorer:${EXPLORER_VERSION}
    environment:
      DATABASE_HOST: explorerdb
      DATABASE_USERNAME: explorer
      DATABASE_PASSWORD: ${EXPLORER_PASSWORD}
      DATABASE_DATABASE: fabricexplorer
    ports:
      - "8080:8080"
volumes:
  explorerdb-data:
EOF
check_success "Hyperledger Explorer Docker Compose setup"

# Let's Encrypt setup for Fabric CA
echo -e "${GREEN}Setting up Let's Encrypt for Fabric CA...${NC}"
mkdir -p $FABRIC_CA_CERT_PATH
certbot certonly --nginx -d fabricca.example.com --non-interactive --agree-tos -m admin@example.com
ln -s /etc/letsencrypt/live/fabricca.example.com/fullchain.pem $FABRIC_CA_CERT_PATH/ca-cert.pem
ln -s /etc/letsencrypt/live/fabricca.example.com/privkey.pem $FABRIC_CA_CERT_PATH/ca-key.pem
check_success "Let's Encrypt certificates setup for Fabric CA"

# Completion message
echo -e "${GREEN}Setup complete. Summary:${NC}"
echo -e "${GREEN}- Docker and Docker Compose installed.${NC}"
echo -e "${GREEN}- Go $GO_VERSION installed.${NC}"
echo -e "${GREEN}- PostgreSQL installed and configured for Hyperledger Explorer.${NC}"
echo -e "${GREEN}- Hyperledger Explorer set up with Docker Compose.${NC}"
echo -e "${GREEN}- Let's Encrypt certificates set up for Fabric CA.${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "1. Start Hyperledger Explorer with:"
echo -e "   cd /home/$USERNAME/hyperledger-explorer && docker-compose up -d"
echo -e "2. Access Explorer at: http://localhost:8080"
echo -e "3. Fabric CA certificates stored in $FABRIC_CA_CERT_PATH."
