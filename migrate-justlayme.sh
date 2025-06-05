#!/bin/bash

# JustLayMe Self-Host Migration Script
# This script migrates your website from Vercel to self-hosted Ubuntu server

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration Variables
DOMAIN="justlay.me"
API_DOMAIN="api.justlay.me"
USER=$(whoami)
HOME_DIR="/home/$USER"
APP_DIR="$HOME_DIR/justlayme"
NGINX_CONFIG="/etc/nginx/sites-available/justlayme"
DB_NAME="justlayme_db"
DB_USER="justlayme_user"
DB_PASS="Local627!"  # Using your password

echo -e "${GREEN}Starting JustLayMe Self-Host Migration...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x
if ! command_exists node; then
    echo -e "${YELLOW}Installing Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
sudo apt install -y nginx postgresql postgresql-contrib redis-server git build-essential python3-certbot-nginx

# Install PM2 globally
if ! command_exists pm2; then
    echo -e "${YELLOW}Installing PM2...${NC}"
    sudo npm install -g pm2
fi

# Clone repository if not exists
if [ ! -d "$APP_DIR" ]; then
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/fastlayne/justlayme.git "$APP_DIR"
else
    echo -e "${YELLOW}Updating repository...${NC}"
    cd "$APP_DIR" && git pull
fi

# Create package.json if it doesn't exist
if [ ! -f "$APP_DIR/package.json" ]; then
    echo -e "${YELLOW}Creating package.json...${NC}"
    cat > "$APP_DIR/package.json" <<'EOF'
{
  "name": "justlayme",
  "version": "1.0.0",
  "description": "JustLayMe - Uncensored AI Chat",
  "main": "character-api.js",
  "scripts": {
    "start": "node character-api.js",
    "dev": "nodemon character-api.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "bcrypt": "^5.1.1",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "axios": "^1.6.2",
    "dotenv": "^16.3.1"
  }
}
EOF
fi

# Install Node.js dependencies
echo -e "${YELLOW}Installing Node.js dependencies...${NC}"
cd "$APP_DIR"
npm install

echo -e "${GREEN}Basic setup complete! Now let's configure the database...${NC}"
echo "Press Enter to continue..."
read

# The rest of the script continues...
echo -e "${YELLOW}To complete setup, run: ./complete-migration.sh${NC}"