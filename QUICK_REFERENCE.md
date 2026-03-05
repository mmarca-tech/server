# Quick Reference Card

Fast commands for common tasks on the home server.

---

## 🚀 Common Commands

### Docker

```bash
# View all containers
docker ps -a

# View logs
docker logs -n 50 <container>  # Last 50 lines
docker logs -f <container>     # Follow logs

# Restart service
docker restart <container>

# Stop/Start
docker stop <service>
docker start <service>

# Rebuild from compose
cd /srv/server/<service>
docker-compose down
docker-compose up -d

# Resource usage
docker stats
```

### Disk Space

```bash
# Check disk usage
df -h

# Find large files/directories
du -sh /srv/server/*
du -sh ~

# Clean Docker images
docker image prune -f
```

### Logs & Monitoring

```bash
# System logs
journalctl -u openclaw-gateway.service -n 50

# Caddy logs
docker logs caddy | grep -i error

# Check failed containers
docker ps -f "status=exited"
```

### Network & DNS

```bash
# Test DNS
nslookup example.com 192.168.1.20
dig example.com @192.168.1.20

# Check open ports
ss -ltnp

# Test service connectivity
curl -I http://localhost:8096  # Jellyfin
curl -I https://example.com    # Via Caddy
```

### File Management

```bash
# Git commit & push
cd /srv/server
/srv/server/git-auto-commit.sh "Your message"

# Backup config
tar -czf /tmp/config-backup.tar.gz /srv/server/*/config/

# View git history
cd /srv/server
git log --oneline -10
```

---

## 🔧 Troubleshooting Quick Fixes

### Service won't start
```bash
docker-compose down
docker-compose up -d --build
docker logs <container>
```

### Database locked
```bash
# Restart database container
docker restart <db_container>
# Check disk space
df -h
```

### High disk usage
```bash
# Find large items
du -sh /srv/server/* | sort -h
docker system prune -a
```

### Network issues
```bash
# Check firewall
sudo ufw status
# Restart networking
docker network ls
docker network prune
```

---

## 📊 Dashboard & Monitoring

```bash
# View dashboard
/srv/openclaw/scripts/dashboard.sh text

# Get JSON status
/srv/openclaw/scripts/dashboard.sh json

# Check Docker maintenance
/srv/openclaw/scripts/docker-maintenance.sh

# Check Home Assistant
/srv/openclaw/scripts/ha-integration.sh
```

---

## 🔐 Security Checks

```bash
# OpenClaw security audit
openclaw security audit

# UFW status
sudo ufw status numbered

# Check credentials permissions
ls -la ~/.openclaw/credentials/

# View running ports
sudo ss -ltnp | grep LISTEN
```

---

## 📝 Documentation Updates

After making changes, always commit:

```bash
cd /srv/server
/srv/server/git-auto-commit.sh "Description of change"
```

---

## 🆘 Emergency Contacts / Escalation

- **OpenClaw issues:** Check logs: `journalctl -u openclaw-gateway.service`
- **Container crashes:** `docker logs <container>` + check disk/memory
- **Network down:** Check cables, router, firewall rules
- **Database issues:** Check disk space first, then restart service

---

## 📞 Support Resources

- Docker docs: https://docs.docker.com
- Caddy docs: https://caddyserver.com/docs
- Jellyfin docs: https://jellyfin.org/docs
- Home Assistant docs: https://www.home-assistant.io/docs
- OpenClaw docs: https://docs.openclaw.ai

