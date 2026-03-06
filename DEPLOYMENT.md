# 🚀 Deployment & Replication Guide

Complete guide to replicate this home server setup on a new machine.

---

## 📋 Prerequisites

### Hardware
- **OS:** Debian 13 (or compatible Linux)
- **Storage:** 500GB+ (for media)
- **RAM:** 4GB minimum, 8GB+ recommended
- **Network:** Static IP or reserved DHCP

### Initial Setup
1. Fresh Debian 13 installation
2. SSH access configured
3. User with sudo privileges (e.g., `manu`)
4. Internet connectivity
5. Domain with DNS access (for Caddy HTTPS)

---

## 🚀 Quick Start (Automated)

```bash
# 1. Clone this repository
git clone <your-repo> /srv/server
cd /srv/server

# 2. Run the master deployment script
sudo ./scripts/deploy-all.sh

# 3. Follow prompts for:
#    - Domain name
#    - Let's Encrypt email
#    - VPN settings (optional)
#    - User configuration
```

---

## 📖 Step-by-Step Manual Setup

### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y curl wget git nano htop tmux

# Create service user (optional, for isolation)
sudo useradd -m -s /bin/bash openclaw || true
```

### Step 2: Install Docker & Docker Compose

```bash
# Use the automated script
./scripts/install-docker.sh

# Or manually:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

### Step 3: Prepare Storage

```bash
# Create media directory structure
sudo mkdir -p /srv/media/{downloads,downloads/movies,downloads/tv,movies,series,music,audiobooks,podcasts}
sudo mkdir -p /srv/server

# Set permissions
sudo chown $USER:$USER /srv/server
sudo chmod 755 /srv/media
```

### Step 4: Clone Repository

```bash
cd /srv/server
git clone <your-repo-url> .

# Or if already in directory:
git init
git remote add origin <your-repo-url>
git fetch origin
git checkout -t origin/main
```

### Step 5: Configure Environment Files

```bash
# Edit each service's .env file
nano proxy/.env          # ROOT_DOMAIN, ACME_EMAIL
nano nextcloud/.env      # DB passwords, secrets
nano immich/.env         # DB passwords
# ... repeat for other services
```

**Key variables to set:**

```bash
# proxy/.env
ROOT_DOMAIN=yourdomain.com
ACME_EMAIL=your-email@example.com

# nextcloud/.env
MYSQL_PASSWORD=strong_password_here
REDIS_PASSWORD=strong_password_here
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=strong_password_here

# immich/.env
DB_PASSWORD=strong_password_here
DB_USERNAME=immich
REDIS_PASSWORD=strong_password_here
```

### Step 6: Start Services

```bash
# Create Docker network
docker network create home-network

# Start all services in order
./scripts/start-all-services.sh

# Or manually:
cd proxy && docker compose up -d
cd ../nextcloud && docker compose up -d
cd ../immich && docker compose up -d
# ... etc
```

### Step 7: Configure Caddy Reverse Proxy

Update DNS records:

```
yourdomain.com    A  your.public.ip
nc.yourdomain.com A  your.public.ip
immich...         A  your.public.ip
jellyfin...       A  your.public.ip
# etc
```

Port forward on router:
```
80 → your-server:80
443 → your-server:443
```

### Step 8: Install OpenClaw

```bash
./scripts/install-openclaw.sh

# Configure
sudo nano /etc/openclaw/openclaw.env

# Start
sudo systemctl start openclaw-gateway
sudo systemctl enable openclaw-gateway
```

### Step 9: Set Up Monitoring & Automation

```bash
# Add cron jobs
sudo crontab -e

# Paste from scripts/crontab-jobs.txt
```

### Step 10: Verify Everything

```bash
# Check all containers
docker ps -a

# Check OpenClaw
systemctl status openclaw-gateway

# Test Caddy
curl -I https://yourdomain.com

# Dashboard
./scripts/dashboard-visual.sh
```

---

## 📂 Directory Structure

After deployment, you'll have:

```
/srv/
├── server/                    # This repository
│   ├── proxy/                # Caddy reverse proxy
│   ├── nextcloud/            # Nextcloud + DB + Redis
│   ├── immich/               # Photo library
│   ├── jellyfin/             # Video streaming
│   ├── jellyseerr/           # Request manager
│   ├── navidrome/            # Music streaming
│   ├── calibre/              # E-book management
│   ├── audiobookshelf/       # Audiobook streaming
│   ├── ha/                   # Home Assistant
│   ├── adguard/              # DNS + ad-blocking
│   ├── transmission/         # Torrent client (VPN via gluetun/ProtonVPN)
│   ├── mollysocket/          # Signal relay
│   ├── scripts/              # Automation & helper scripts
│   └── DEPLOYMENT.md         # This file
│
└── media/                     # Shared media storage
    ├── downloads/            # Transmission downloads
    │   ├── movies/
    │   └── tv/
    ├── movies/              # Jellyfin movie library
    ├── series/              # Jellyfin series library
    ├── music/               # Navidrome + Jellyfin music
    ├── audiobooks/          # Audiobookshelf + Jellyfin audiobooks
    └── podcasts/            # Podcast storage
```

---

## 🔧 Available Scripts

### Automated Deployment

```bash
./scripts/deploy-all.sh              # Full automated setup
./scripts/install-docker.sh          # Docker installation
./scripts/install-openclaw.sh        # OpenClaw setup
./scripts/start-all-services.sh      # Start all containers
./scripts/stop-all-services.sh       # Stop all containers
./scripts/backup-all-services.sh     # Backup all data
```

### Monitoring & Management

```bash
./scripts/dashboard-visual.sh        # Visual status dashboard
./scripts/docker-maintenance.sh      # Docker health check
./scripts/docker-check-updates.sh    # Image update check
./scripts/caddy-cert-monitor.sh      # SSL certificate check
./scripts/ha-integration.sh          # Home Assistant status
./scripts/media-library-mgmt.sh      # Media service status
./scripts/generate-monitoring-report.sh  # Daily report
```

### Utilities

```bash
./scripts/git-auto-commit.sh "message"  # Git commit & push
./scripts/logs.sh <service>             # View service logs
```

---

## 📦 Backup & Restore

### Create Backup

```bash
./scripts/backup-all-services.sh

# Creates timestamped backup:
# /srv/backups/backup-2026-03-05-120000.tar.gz
```

### Restore from Backup

```bash
./scripts/restore-backup.sh /path/to/backup.tar.gz
```

---

## 🔐 Security Hardening

After deployment, run:

```bash
# Security audit
openclaw security audit --deep

# Enable automatic updates
sudo apt install unattended-upgrades

# Harden firewall
sudo ufw enable
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

---

## 🚨 Troubleshooting

### Services won't start

```bash
# Check Docker
docker ps -a
docker logs <container-name>

# Check disk space
df -h
du -sh /srv/*

# Check permissions
ls -la /srv/server/*/config/
```

### Caddy not getting certificates

```bash
# Check logs
docker logs caddy_fresh-caddy-1

# Verify DNS
nslookup yourdomain.com

# Check port forwarding
curl -I http://your-public-ip
```

### Database errors

```bash
# Restart database
docker restart nextcloud_fresh-nextcloud-db-1

# Check disk space
df -h /srv/

# View database logs
docker logs nextcloud_fresh-nextcloud-db-1
```

### OpenClaw not connecting

```bash
# Check service status
systemctl status openclaw-gateway

# Check logs
journalctl -u openclaw-gateway.service -n 50

# Verify credentials
ls -la ~/.openclaw/credentials/
```

---

## 📊 Performance Tuning

### Docker Limits

Edit service `docker-compose.yml`:

```yaml
services:
  service-name:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

### Database Optimization

```bash
# Nextcloud database tuning
docker exec nextcloud_fresh-nextcloud-db-1 mysql-optimize

# Immich database tuning
docker exec immich_fresh-immich-db-1 psql-optimize
```

---

## 🔄 Upgrades & Updates

### Update All Images

```bash
cd /srv/server

# Pull latest images
./scripts/pull-all-images.sh

# Restart services
./scripts/restart-all-services.sh

# Verify
./scripts/dashboard-visual.sh
```

### Update OpenClaw

```bash
sudo openclaw update status
npm update -g openclaw
sudo systemctl restart openclaw-gateway
```

---

## 📞 Support & Documentation

- [INFRASTRUCTURE.md](INFRASTRUCTURE.md) — System architecture
- [SERVICES.md](SERVICES.md) — Service-specific docs
- [OPENCLAW_AUTOMATION.md](OPENCLAW_AUTOMATION.md) — Automation guide
- [DASHBOARD.md](DASHBOARD.md) — Dashboard usage
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Common commands

---

## 📝 Notes

- **First deployment:** Allow 30-60 minutes for full setup
- **DNS propagation:** May take 5-30 minutes for Let's Encrypt validation
- **Database initialization:** First startup of databases may take 2-5 minutes
- **Media indexing:** First scan of large libraries can take hours (Jellyfin, Immich, Navidrome)

---

## 🚀 Next Steps After Deployment

1. Access web UIs:
   - Nextcloud: https://nc.yourdomain.com
   - Jellyfin: https://jellyfin.yourdomain.com
   - Immich: https://immich.yourdomain.com
   - Transmission: https://transmission.yourdomain.com

2. Configure each service

3. Install mobile apps and test sync

4. Set up monitoring alerts

5. Schedule regular backups

6. Review security audit logs

---

## 📌 Version History

- **2026-03-05** — Initial deployment guide created

