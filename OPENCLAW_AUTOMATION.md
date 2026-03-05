# OpenClaw Automation Suite

Complete automation setup for your home server with monitoring, documentation, and git-based version control.

---

## 🎯 What's Automated?

### Daily Jobs (via Crontab)

| Time | Task | Script | Purpose |
|------|------|--------|---------|
| 2:00 AM | Package updates | `apt upgrade` | Keep system patched |
| 3:00 AM | Docker maintenance | `docker-maintenance.sh` | Image updates, error logs, cleanup |
| 4:00 AM (Sun) | Certificate check | `caddy-cert-monitor.sh` | SSL expiry warnings |
| 6:00 AM | Docker image updates | `check-docker-updates.sh` | Check if newer versions available |
| 7:00 AM | Home Assistant check | `ha-integration.sh` | HA status & sensor data |
| 8:00 AM | Media library health | `media-library-mgmt.sh` | Jellyfin/Immich/Navidrome status |
| 9:00 AM | Monitoring report | `generate-monitoring-report.sh` | Daily system snapshot + git commit |

### Outputs

```
~/.openclaw/logs/
├── docker-update-check.log
├── docker-maintenance.log
├── caddy-cert-monitor.log
├── ha-integration.log
├── media-library-mgmt.log
└── docker-image-check.log

/srv/server/MONITORING_REPORTS/
├── 2026-03-05.md (daily snapshots)
├── 2026-03-06.md
└── ...
```

---

## 📚 Documentation System

All infrastructure docs live in `/srv/server/` (a git repository).

### Files

- **INFRASTRUCTURE.md** — Architecture, security, service matrix
- **SERVICES.md** — Per-service docs, configs, troubleshooting
- **QUICK_REFERENCE.md** — Common commands & quick fixes
- **MONITORING_REPORTS/** — Daily system snapshots (auto-generated)
- **README.md** — Setup overview, Make targets

### Git Management

Every change is version-controlled:

```bash
cd /srv/server

# After updating docs:
/srv/server/git-auto-commit.sh "Your change description"

# View history:
git log --oneline -20

# See what changed:
git diff HEAD~1

# Revert a change:
git reset --hard <commit-hash>
```

---

## 🔌 Dashboard

### Text Dashboard

```bash
/srv/openclaw/scripts/dashboard.sh text
```

Shows:
- Docker containers status
- Disk usage
- Service uptime
- System info

### JSON Dashboard

```bash
/srv/openclaw/scripts/dashboard.sh json
```

Machine-readable format for integration.

### Canvas Dashboard

```bash
/srv/openclaw/scripts/canvas-dashboard.sh
```

Structured data for visual dashboards (OpenClaw Canvas).

---

## 📊 Monitoring Reports

### Daily Report

Auto-generated every day at 9:00 AM:

```
/srv/server/MONITORING_REPORTS/2026-03-05.md
```

Contains:
- Docker container status
- Disk usage snapshot
- Memory/CPU usage
- Recent errors in logs
- Network listening ports
- System uptime
- Trends compared to yesterday

### Reviewing Reports

```bash
# View today's report
cat /srv/server/MONITORING_REPORTS/$(date +%Y-%m-%d).md

# View history
ls -la /srv/server/MONITORING_REPORTS/

# Search all reports for errors
grep -r "error" /srv/server/MONITORING_REPORTS/

# See how many errors per day
for f in /srv/server/MONITORING_REPORTS/*.md; do
    count=$(grep -c "error" "$f")
    echo "$(basename $f): $count errors"
done
```

---

## 🔔 Telegram Notifications

All automation outputs flow to you via Telegram (via OpenClaw).

### What You Get

- ✅ Service health status
- ⚠️ Errors & warnings
- 📈 Certificate expiry alerts
- 💾 Disk usage warnings
- 📊 Daily summary (optional)

### Disabling Alerts

Edit each script to remove notification section, or modify OpenClaw config:

```bash
openclaw config show | grep -i telegram
```

---

## 🔧 Adding New Automations

### 1. Create a script

```bash
cat > /srv/openclaw/scripts/my-job.sh << 'EOF'
#!/bin/bash
# Your automation logic here
echo "Task completed: $(date)"
EOF

chmod +x /srv/openclaw/scripts/my-job.sh
```

### 2. Add to crontab

```bash
sudo crontab -e
```

Add a line:
```bash
0 10 * * * /srv/openclaw/scripts/my-job.sh >> /tmp/my-job.log 2>&1
```

### 3. Document it

Edit `INFRASTRUCTURE.md` → add to cron schedule table.

Commit:
```bash
cd /srv/server
/srv/server/git-auto-commit.sh "Add my-job automation"
```

---

## 🛠️ Troubleshooting

### Cron job not running

```bash
# Check crontab
sudo crontab -l

# Check logs
sudo journalctl -u cron -n 50

# Test script manually
/srv/openclaw/scripts/docker-maintenance.sh
```

### Script fails

Check the log file:
```bash
tail -50 /tmp/docker-maint.log
docker logs caddy | grep error
```

### Git commit fails

```bash
# Set git config
git config --global user.email "manu@hal-9000"
git config --global user.name "manu"

# Retry
/srv/server/git-auto-commit.sh "Retry message"
```

### Documentation out of sync

Always run after manual changes:
```bash
/srv/server/git-auto-commit.sh "Manual update: describe what changed"
```

---

## 📝 Best Practices

### 1. Document as you go
Don't wait until the end. Update docs immediately after:
- Installing a new service
- Changing configuration
- Fixing a bug
- Adding a cron job

### 2. Commit frequently
```bash
/srv/server/git-auto-commit.sh "Single focused change"
```

Avoid large multi-service commits.

### 3. Keep monitoring reports
These are your audit trail. Review them weekly:
```bash
# Weekly review
cat /srv/server/MONITORING_REPORTS/$(date -d "-7 days" '+%Y-%m-%d').md
```

### 4. Test scripts before cron
```bash
# Test manually first
/srv/openclaw/scripts/my-new-job.sh

# Check output
echo $?  # Should be 0 for success

# Then add to crontab
```

### 5. Review git history
Before restarting a service or making big changes:
```bash
cd /srv/server
git log --oneline -10
git show <commit-hash>
```

---

## 🎯 Next Steps

1. **Add your DNS records** — Update SERVICES.md with your actual domain
2. **Configure Home Assistant token** — Place in `~/.openclaw/.ha_token`
3. **Set up git remote** (optional) — Push to GitHub/GitLab for backup
4. **Enable TTS notifications** — Replace plain text alerts with voice
5. **Create custom dashboards** — Build Canvas visualizations

---

## 📖 Related Docs

- [INFRASTRUCTURE.md](INFRASTRUCTURE.md) — Full system overview
- [SERVICES.md](SERVICES.md) — Service-specific guides
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Fast commands
- [SETUP_GUIDE.md](SETUP_GUIDE.md) — Initial setup

