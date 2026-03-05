# 🔧 Server Scripts Directory

Automation and deployment scripts for home server management.

---

## 🚀 Deployment Scripts

Used to set up a new server from scratch.

### `deploy-all.sh`
**Full automated deployment** (recommended for first-time setup)

```bash
sudo ./scripts/deploy-all.sh
```

Handles:
- System update
- Docker installation
- Directory structure creation
- Environment file setup
- Service startup
- OpenClaw installation
- Monitoring setup

**Duration:** 30-60 minutes

### `install-docker.sh`
**Install Docker & Docker Compose only**

```bash
sudo ./scripts/install-docker.sh
```

Use if Docker isn't installed or you want to upgrade.

### `start-all-services.sh`
**Start all Docker services in correct order**

```bash
./scripts/start-all-services.sh
```

Brings up:
- Caddy (reverse proxy)
- Nextcloud
- Immich
- Jellyfin
- All other services

### `setup-monitoring.sh`
**Add monitoring and automation cron jobs**

```bash
./scripts/setup-monitoring.sh
```

Installs daily scheduled tasks:
- Package updates
- Docker maintenance
- Certificate checks
- Monitoring reports

### `install-openclaw.sh`
**Install and configure OpenClaw as systemd service**

```bash
./scripts/install-openclaw.sh
```

Sets up:
- Node.js (if needed)
- OpenClaw globally
- Systemd service unit
- Log directories

---

## 📊 Monitoring Scripts

Check system health and generate reports.

### `dashboard-visual.sh`
**Real-time visual dashboard**

```bash
./scripts/dashboard-visual.sh

# Or live updates
watch -n 5 ./scripts/dashboard-visual.sh
```

Shows:
- Docker container status
- Disk usage
- Memory usage
- System uptime

### `docker-maintenance.sh`
**Check Docker image updates and errors**

```bash
./scripts/docker-maintenance.sh
```

Reports:
- Available image updates
- Exited containers
- Recent errors in logs
- Cleanup status

### `check-docker-updates.sh`
**Detailed Docker image update checker**

```bash
./scripts/check-docker-updates.sh
```

### `caddy-cert-monitor.sh`
**SSL certificate expiration monitor**

```bash
./scripts/caddy-cert-monitor.sh
```

Alerts when certificates:
- Expire soon (<30 days)
- Are already expired
- Need renewal

### `ha-integration.sh`
**Home Assistant health check**

```bash
./scripts/ha-integration.sh
```

### `media-library-mgmt.sh`
**Media service health check**

```bash
./scripts/media-library-mgmt.sh
```

Checks:
- Jellyfin indexing status
- Immich ML service
- Navidrome library
- Disk space

### `generate-monitoring-report.sh`
**Daily system snapshot report**

```bash
./scripts/generate-monitoring-report.sh
```

Generates timestamped reports in:
`/srv/server/MONITORING_REPORTS/YYYY-MM-DD.md`

---

## 🔍 Torrent Search & Download

### `torrent-search.sh`
**Non-interactive torrent search for OpenClaw/Telegram integration**

```bash
# Search torrents (returns JSON)
./scripts/torrent-search.sh search "movie name"

# Download via Transmission
./scripts/torrent-search.sh download "magnet:?xt=urn:btih:..." /srv/media/downloads/movies

# List active Transmission torrents
./scripts/torrent-search.sh status

# Resolve magnet from 1337x page (they don't expose magnets on search)
./scripts/torrent-search.sh resolve "https://www.1337x.to/torrent/..."
```

**Sources:** TPB, 1337x, Nyaa  
**Output:** JSON array with id, source, name, size, seeds, magnet link  
**Transmission:** Connects to `127.0.0.1:9091` (local Docker container)

**OpenClaw Integration:**
- Ask the agent to search for a torrent via Telegram
- Agent runs the script, presents numbered results with inline buttons
- Select a result → agent sends magnet to Transmission
- Supports download categories: movies, tv, general

**Environment Variables:**
- `TR_HOST` — Transmission host (default: `127.0.0.1`)
- `TR_PORT` — Transmission port (default: `9091`)
- `TR_USER` / `TR_PASS` — Auth credentials (if required)

---

## 🛠️ Utility Scripts

Helper scripts for common tasks.

### `git-auto-commit.sh`
**Commit and push documentation changes**

```bash
./scripts/git-auto-commit.sh "Describe your change"
```

Automatically:
- Stages all changes
- Creates git commit
- Pushes to remote

### `logs.sh`
**View service logs easily**

```bash
./scripts/logs.sh <service>
./scripts/logs.sh nextcloud
./scripts/logs.sh caddy

# Follow logs in real-time
./scripts/logs.sh jellyfin -f
```

### `up-all.sh`
**Start all services**

```bash
./scripts/up-all.sh
```

### `down-all.sh`
**Stop all services**

```bash
./scripts/down-all.sh
```

### `pull-all.sh`
**Update all Docker images**

```bash
./scripts/pull-all.sh
```

---

## 📋 Usage Guide

### For New Server Setup

```bash
# 1. Clone repository
git clone <your-repo> /srv/server
cd /srv/server

# 2. Run automated deployment
sudo ./scripts/deploy-all.sh

# 3. Follow prompts and configure .env files
```

### For Daily Operations

```bash
# Check dashboard
./scripts/dashboard-visual.sh

# View specific service logs
./scripts/logs.sh jellyfin

# Commit documentation updates
./scripts/git-auto-commit.sh "Update documentation"
```

### For Maintenance

```bash
# Check docker health
./scripts/docker-maintenance.sh

# Check certificates
./scripts/caddy-cert-monitor.sh

# Update all images
./scripts/pull-all.sh

# Restart services
./scripts/down-all.sh && ./scripts/up-all.sh
```

### For Monitoring

```bash
# Live dashboard (every 5 seconds)
watch -n 5 ./scripts/dashboard-visual.sh

# Generate daily report
./scripts/generate-monitoring-report.sh

# View reports
cat /srv/server/MONITORING_REPORTS/$(date +%Y-%m-%d).md
```

---

## 🔐 Required Permissions

- **Deployment scripts:** Must run with `sudo`
- **Service scripts:** Run as regular user
- **Git scripts:** Requires git config (name + email)
- **Cron jobs:** Installed via `setup-monitoring.sh`

---

## 📝 Environment Configuration

Before running deployment, prepare these files:

```bash
# Domain and email (critical)
proxy/.env                 # ROOT_DOMAIN, ACME_EMAIL

# Database passwords (security-sensitive)
nextcloud/.env            # DB passwords
immich/.env               # DB passwords
```

Generate secure passwords:

```bash
openssl rand -base64 32
```

---

## 🚨 Troubleshooting

### Script fails with "command not found"

```bash
# Make sure you're in the right directory
cd /srv/server

# Make scripts executable
chmod +x scripts/*.sh
```

### Permission denied

```bash
# Deployment scripts need sudo
sudo ./scripts/deploy-all.sh

# Service scripts run as user
./scripts/start-all-services.sh
```

### Docker compose not found

```bash
# Reinstall Docker
sudo ./scripts/install-docker.sh

# Or use docker compose (new syntax)
docker compose --version
```

---

## 📚 Related Documentation

- [DEPLOYMENT.md](../DEPLOYMENT.md) — Full deployment guide
- [INFRASTRUCTURE.md](../INFRASTRUCTURE.md) — System architecture
- [SERVICES.md](../SERVICES.md) — Service-specific info
- [DASHBOARD.md](../DASHBOARD.md) — Dashboard usage

---

## 🔄 Backup & Restore

```bash
# Create backup
sudo tar -czf /srv/backups/backup-$(date +%Y-%m-%d).tar.gz /srv/server /srv/media

# Restore from backup
sudo tar -xzf /srv/backups/backup-2026-03-05.tar.gz -C /
```

---

## 📞 Support

If a script fails:

1. **Check logs:**
   ```bash
   docker logs <container-name>
   journalctl -xe
   ```

2. **Read the error message carefully** — Most provide solutions

3. **Review documentation:**
   - [DEPLOYMENT.md](../DEPLOYMENT.md)
   - [QUICK_REFERENCE.md](../QUICK_REFERENCE.md)

4. **Check system resources:**
   ```bash
   ./scripts/dashboard-visual.sh
   ```

---

## 📌 Version & Updates

These scripts are version-controlled. Check the latest:

```bash
cd /srv/server
git log --oneline scripts/
```

Update to latest:

```bash
git pull origin main
chmod +x scripts/*.sh
```

