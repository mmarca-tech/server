#!/bin/bash

# Master Deployment Script
# Automates full home server setup from scratch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     🖥️  HOME SERVER DEPLOYMENT SCRIPT${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}This script must be run with sudo${NC}"
   exit 1
fi

# Gather configuration
echo -e "${YELLOW}📋 Configuration Setup${NC}"
echo ""

read -p "Enter your domain (e.g., example.com): " DOMAIN
read -p "Enter Let's Encrypt email: " ACME_EMAIL
read -p "Enter username (default: manu): " USERNAME
USERNAME=${USERNAME:-manu}

echo ""
echo -e "${YELLOW}🔧 Step 1: System Update${NC}"
apt update && apt upgrade -y
apt install -y curl wget git nano htop tmux

echo ""
echo -e "${YELLOW}🐳 Step 2: Installing Docker${NC}"
bash /srv/server/scripts/install-docker.sh

echo ""
echo -e "${YELLOW}📁 Step 3: Creating Directory Structure${NC}"
mkdir -p /srv/media/{downloads,downloads/movies,downloads/tv,movies,series,music,audiobooks,podcasts}
mkdir -p /srv/{sonarr,radarr,prowlarr}/config
chown -R "$USERNAME:$USERNAME" /srv/{sonarr,radarr,prowlarr}
mkdir -p /srv/server

echo "✅ Directory structure created"

echo ""
echo -e "${YELLOW}🌐 Step 4: Setting Environment Variables${NC}"

# Create .env files for each service
cat > /srv/server/proxy/.env << EOF
ROOT_DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL
EOF

cat > /srv/server/transmission/.env << EOF
TZ=Europe/Tallinn
DISABLE_VPN=true
EOF

echo "✅ Environment files created"
echo ""
echo -e "${YELLOW}📝 Step 5: Manual Configuration Required${NC}"
echo "Please edit these files with your actual values:"
echo ""
echo "  nano /srv/server/proxy/.env"
echo "  nano /srv/server/nextcloud/.env"
echo "  nano /srv/server/immich/.env"
echo ""
read -p "Press ENTER when you've configured all .env files: "

echo ""
echo -e "${YELLOW}🐳 Step 6: Creating Docker Network${NC}"
docker network create home-network 2>/dev/null || echo "Network already exists"

echo ""
echo -e "${YELLOW}🚀 Step 7: Starting Services${NC}"
bash /srv/server/scripts/start-all-services.sh

echo ""
echo -e "${YELLOW}⏱️  Waiting for services to initialize...${NC}"
sleep 30

echo ""
echo -e "${YELLOW}🔐 Step 8: Installing OpenClaw${NC}"
bash /srv/server/scripts/install-openclaw.sh

echo ""
echo -e "${YELLOW}📊 Step 9: Setting Up Monitoring${NC}"
bash /srv/server/scripts/setup-monitoring.sh

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Verify services:"
echo "   docker ps -a"
echo ""
echo "2. Check dashboard:"
echo "   /srv/server/scripts/dashboard-visual.sh"
echo ""
echo "3. Configure DNS and port forwarding:"
echo "   - Point $DOMAIN to your public IP"
echo "   - Forward ports 80 and 443 to this server"
echo ""
echo "4. Access your services:"
echo "   - Nextcloud: https://nc.$DOMAIN"
echo "   - Jellyfin: https://jellyfin.$DOMAIN"
echo "   - Transmission: https://transmission.$DOMAIN"
echo "   - Sonarr (LAN): http://SERVER_IP:8989"
echo "   - Radarr (LAN): http://SERVER_IP:7878"
echo "   - Prowlarr (LAN): http://SERVER_IP:9696"
echo "   - Jellyseerr: https://jellyseerr.$DOMAIN / http://SERVER_IP:5055"
echo ""
echo "5. Review documentation:"
echo "   - /srv/server/DEPLOYMENT.md"
echo "   - /srv/server/INFRASTRUCTURE.md"
echo "   - /srv/server/SERVICES.md"
echo ""
