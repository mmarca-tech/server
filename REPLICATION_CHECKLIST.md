# ✅ Server Replication Checklist

Complete guide to replicate this home server setup on a new machine.

---

## 📚 Documentation Structure

All files are version-controlled in git for easy replication.

### Main Documentation

| Document | Purpose |
|----------|---------|
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Step-by-step setup guide for new server |
| **[INFRASTRUCTURE.md](INFRASTRUCTURE.md)** | System architecture & overview |
| **[SERVICES.md](SERVICES.md)** | Individual service documentation |
| **[DASHBOARD.md](DASHBOARD.md)** | Monitoring dashboard usage |
| **[OPENCLAW_AUTOMATION.md](OPENCLAW_AUTOMATION.md)** | Automation & cron jobs |
| **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** | Common commands & quick fixes |

### Scripts Documentation

| Script | Location | Purpose |
|--------|----------|---------|
| **Deploy All** | `scripts/deploy-all.sh` | Automated full setup (recommended) |
| **Install Docker** | `scripts/install-docker.sh` | Docker & Docker Compose installation |
| **Start Services** | `scripts/start-all-services.sh` | Bring up all containers |
| **Setup Monitoring** | `scripts/setup-monitoring.sh` | Configure cron jobs & automation |
| **Install OpenClaw** | `scripts/install-openclaw.sh` | OpenClaw gateway setup |

---

## 🚀 Fastest Path to Replication

```bash
# 1. Clone repository
git clone <your-repo-url> /srv/server
cd /srv/server

# 2. Run automated setup
sudo ./scripts/deploy-all.sh

# 3. Follow prompts, configure .env files, done!
```

**Time:** 30-60 minutes from zero to fully working server

---

## 📊 What's Replicated

✅ 12 containerized services  
✅ Reverse proxy with HTTPS  
✅ Daily monitoring & automation  
✅ Complete documentation  
✅ Git-version-controlled setup  
✅ Transmission with shared downloads  
✅ Visual dashboard  

---

## 📌 Key Files for Replication

```
/srv/server/
├── DEPLOYMENT.md                    ← START HERE
├── REPLICATION_CHECKLIST.md         ← You are here
├── INFRASTRUCTURE.md                ← Architecture overview
├── SERVICES.md                      ← Per-service docs
├── scripts/
│   ├── deploy-all.sh               ← Main deployment script
│   ├── README.md                   ← Scripts documentation
│   └── ... (other scripts)
├── proxy/
│   ├── docker-compose.yml          ← Caddy setup
│   └── Caddyfile                   ← Reverse proxy config
├── transmission/                    ← Torrent client (VPN via gluetun)
├── sonarr/                         ← TV show automation
├── radarr/                         ← Movie automation
├── prowlarr/                       ← Indexer manager
├── flaresolverr/                   ← Cloudflare bypass for Prowlarr
├── bazarr/                         ← Automatic subtitle downloads
├── tdarr/                          ← Media transcoding
├── recyclarr/                      ← TRaSH quality profile sync
├── jellyseerr/                     ← Media request UI
├── nextcloud/
├── jellyfin/
└── ... (other services)
```

---

## ⚡ TL;DR - 5 Minute Quick Start

```bash
# Only for people who know what they're doing:

git clone <repo> /srv/server && cd /srv/server
sudo ./scripts/deploy-all.sh
# Answer prompts, edit .env files when prompted
# Wait 30-60 minutes
# Access dashboard: ./scripts/dashboard-visual.sh
# Read: DEPLOYMENT.md
```

For detailed step-by-step: **READ DEPLOYMENT.md**

---

## ✅ Prerequisites Checklist

Before running deploy-all.sh:

- [ ] Debian 13 (or compatible Linux)
- [ ] User with sudo privileges  
- [ ] Internet connectivity
- [ ] SSH access working
- [ ] Domain name registered
- [ ] 500GB+ storage available
- [ ] Root/admin access

---

## 🎯 After Deployment

1. **Verify:** `./scripts/dashboard-visual.sh`
2. **Check logs:** `./scripts/logs.sh <service>`
3. **Test services:** Visit each subdomain (nc, jellyfin, etc.)
4. **Read docs:** DEPLOYMENT.md → INFRASTRUCTURE.md → SERVICES.md

---

## 📞 If Something Breaks

1. Check logs: `docker logs <container>`
2. Read DEPLOYMENT.md troubleshooting section
3. Run dashboard: `./scripts/dashboard-visual.sh`
4. Check git history: `git log --oneline -10`

---

## 🔄 Updates & Customization

Everything is git-controlled. After setup:

```bash
# Update documentation
nano DEPLOYMENT.md
./scripts/git-auto-commit.sh "Updated deployment guide"

# Add new service
# See SERVICES.md for template

# Add cron job
# Edit scripts/setup-monitoring.sh
./scripts/git-auto-commit.sh "Added new cron job"
```

---

**Start with:** [DEPLOYMENT.md](DEPLOYMENT.md)

