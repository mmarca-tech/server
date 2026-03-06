# Home Server Infrastructure

**Last Updated:** 2026-03-05

## Overview

Home server running on a Debian 13 laptop with Docker Compose, Caddy reverse proxy, and OpenClaw automation.

**Host:** hal-9000 (192.168.1.20)  
**Domain:** [configured in Caddyfile]  
**Uptime:** Always-on  

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         Home Server (Debian 13)         │
│  • 1 trusted user (manu)                │
│  • OpenClaw running as systemd service  │
│  • Docker Compose for containerized apps│
└─────────────────────────────────────────┘
         │
         ├─→ Caddy (Reverse Proxy)
         │   ├─ HTTPS (443)
         │   ├─ HTTP (80)
         │   └─ Secure headers + compression
         │
         ├─→ Docker Containers
         │   ├─ Media (Jellyfin, Immich, Navidrome)
         │   ├─ Downloads (Transmission + gluetun VPN)
         │   ├─ Smart Home (Home Assistant)
         │   ├─ Utilities (Nextcloud, Calibre)
         │   ├─ Ad-blocking (AdGuard)
         │   └─ Databases (MariaDB, Redis, PostgreSQL)
         │
         └─→ OpenClaw
             ├─ Automation & monitoring
             ├─ Telegram notifications
             └─ Git-backed documentation
```

---

## 🐳 Services

### Media & Entertainment

| Service | Container | Port | Status | Notes |
|---------|-----------|------|--------|-------|
| **Jellyfin** | jellyfin | 8096 | ✅ | Video streaming, auto-indexing |
| **Immich** | immich-server | 2283 | ✅ | Photos/videos, ML indexing |
| **Navidrome** | navidrome | 4533 | ✅ | Music streaming |
| **Jellyseerr** | jellyseerr | 5055 | ✅ | Request/wishlist management |
| **Audiobookshelf** | audiobookshelf | 80 | ✅ | Audiobook library |
| **Calibre** | calibre-web | 8083 | ✅ | E-book management |
| **Transmission** | transmission | 9091 | ✅ | Torrent client (via gluetun VPN) |
| **Gluetun** | gluetun | - | ✅ | ProtonVPN WireGuard sidecar for Transmission |

### Smart Home & Utilities

| Service | Container | Port | Status | Notes |
|---------|-----------|------|--------|-------|
| **Home Assistant** | homeassistant | 8123 | ✅ | LAN only + reverse proxy |
| **Nextcloud** | nextcloud | 80 | ✅ | File sync + productivity |
| **MollySocket** | mollysocket | - | ✅ | Signal messaging relay |
| **AdGuard** | adguard | 3001 (UI) | ✅ | DNS + ad-blocking |

### Infrastructure

| Service | Container | Port | Status | Notes |
|---------|-----------|------|--------|-------|
| **Caddy** | caddy | 80, 443, 2019 | ✅ | Reverse proxy + HTTPS |
| **Databases** | Various | Internal | ✅ | MariaDB, Redis, PostgreSQL |

---

## 🔐 Security

### Firewall Rules (UFW)

```
SSH (22)       → Allow from 192.168.1.0/24 (LAN only)
HTTP (80)      → Allow from anywhere (reverse proxy)
HTTPS (443)    → Allow from anywhere (reverse proxy)
OpenClaw (18789) → Deny (loopback only)
Home Assistant (8123) → Allow from LAN + Docker networks
AdGuard (3001) → Allow from 192.168.1.0/24 (LAN only)
DNS (53)       → AdGuard (restrict if needed)
```

### Credentials

- **OpenClaw tokens** → `~/.openclaw/credentials/` (chmod 700)
- **Home Assistant token** → `~/.openclaw/.ha_token` (for API access)
- **Docker secrets** → `.env` files (not in git)

### Access Control

- Single trusted user (manu)
- SSH key-based auth (no passwords)
- Telegram bot for alerts only (no admin commands)
- Docker socket restricted to manu user

---

## 📊 Monitoring & Automation

### Cron Jobs

| Time | Task | Script | Frequency |
|------|------|--------|-----------|
| 2:00 AM | Package updates | `apt upgrade` | Daily |
| 3:00 AM | Docker maintenance | `docker-maintenance.sh` | Daily |
| 4:00 AM Sun | Certificate check | `caddy-cert-monitor.sh` | Weekly |
| 6:00 AM | Docker image updates | `check-docker-updates.sh` | Daily |
| 7:00 AM | Home Assistant status | `ha-integration.sh` | Daily |
| 8:00 AM | Media library health | `media-library-mgmt.sh` | Daily |

### Telegram Alerts

- Service health (errors, restarts)
- Certificate expiry warnings
- Disk usage alerts (>80%)
- Docker image updates available

---

## 💾 Backup Strategy

**Current Status:** To be documented

- [ ] Database backups (daily)
- [ ] Configuration backups (weekly)
- [ ] Media snapshots (monthly)
- [ ] Backup verification (automated)

---

## 🔧 Troubleshooting Guides

### Issue: Container keeps crashing

1. Check logs: `docker logs -n 50 <container>`
2. Check disk space: `df -h`
3. Check memory: `docker stats`
4. Restart: `docker restart <container>`
5. If persistent, check `/srv/server/<service>/` config

### Issue: DNS not resolving

1. Verify AdGuard running: `docker ps | grep adguard`
2. Check firewall: `sudo ufw status | grep 53`
3. Test DNS: `nslookup google.com 192.168.1.20`

### Issue: HTTPS certificate issues

1. Check cert expiry: `docker exec caddy openssl x509 -in /root/.local/share/caddy -noout -enddate`
2. Reload Caddy: `docker restart caddy`
3. Check logs: `docker logs caddy | tail -50`

### Issue: SSH access denied

1. Check UFW rule: `sudo ufw status numbered | grep 22`
2. Check SSH service: `sudo systemctl status ssh`
3. Check firewall: `sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp`

---

## 📝 Recent Changes

- **2026-03-05**: Added OpenClaw automation suite (docker, caddy, ha, media monitoring)
- **2026-03-05**: Security hardening (credentials chmod, auto-updates enabled)
- **2026-03-05**: Fixed UFW SSH access issues

---

## 📚 Related Files

- **Services config**: `/srv/server/*/docker-compose.yml`
- **Proxy config**: `/srv/server/proxy/Caddyfile`
- **OpenClaw scripts**: `/srv/openclaw/scripts/`
- **Automation logs**: `~/.openclaw/logs/`

