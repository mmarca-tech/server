#!/bin/bash

# Master Deployment Script
# Automates full home server setup from scratch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"

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
bash "$SCRIPT_DIR/install-docker.sh"

echo ""
echo -e "${YELLOW}📁 Step 3: Creating Directory Structure${NC}"
mkdir -p /srv/media/{downloads,downloads/incomplete,movies,series,music,audiobooks,podcasts}
mkdir -p /srv/{sonarr,radarr,prowlarr,bazarr}/config
mkdir -p /srv/tdarr/{server,configs,logs,transcode_cache}
mkdir -p /srv/recyclarr/config
chown -R "$USERNAME:$USERNAME" /srv/{sonarr,radarr,prowlarr,bazarr,tdarr,recyclarr}
mkdir -p /srv/server

echo "✅ Directory structure created"

echo ""
echo -e "${YELLOW}🌐 Step 4: Setting Environment Variables${NC}"

# Copy all .env.example -> .env for services that don't have one yet
for example in "$SERVER_DIR"/*/.env.example; do
    dir="$(dirname "$example")"
    [ ! -f "$dir/.env" ] && cp "$example" "$dir/.env"
done

# Overwrite proxy .env with values from this run
cat > "$SERVER_DIR/proxy/.env" << EOF
ROOT_DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL
CADDY_IMAGE=caddy:2.8.4
EOF

echo "✅ Environment files created"
echo ""
echo -e "${YELLOW}📝 Step 5: Manual Configuration Required${NC}"
echo "Please edit these files with your actual values:"
echo ""
echo "  nano $SERVER_DIR/nextcloud/.env"
echo "  nano $SERVER_DIR/immich/.env"
echo ""
read -p "Press ENTER when you've configured all .env files: "

echo ""
echo -e "${YELLOW}🐳 Step 6: Creating Docker Networks${NC}"
docker network create home-network 2>/dev/null || echo "home-network already exists"
docker network create proxy 2>/dev/null || echo "proxy network already exists"

echo ""
echo -e "${YELLOW}🚀 Step 7: Starting Services${NC}"
bash "$SCRIPT_DIR/start-all-services.sh"

echo ""
echo -e "${YELLOW}⏱️  Waiting for services to initialize...${NC}"
sleep 30

echo ""
echo -e "${YELLOW}🔐 Step 8: Installing OpenClaw${NC}"
bash "$SCRIPT_DIR/install-openclaw.sh"

echo ""
echo -e "${YELLOW}📊 Step 9: Setting Up Monitoring${NC}"
bash "$SCRIPT_DIR/setup-monitoring.sh"

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
echo "   $SCRIPT_DIR/dashboard-visual.sh"
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
echo "   - $SERVER_DIR/DEPLOYMENT.md"
echo "   - $SERVER_DIR/INFRASTRUCTURE.md"
echo "   - $SERVER_DIR/SERVICES.md"
echo ""
