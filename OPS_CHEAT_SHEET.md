# Operations Cheat Sheet

```bash
# All containers and published ports
./scripts/stack.sh status

# Reconcile every configured stack
./scripts/stack.sh up

# Stop in reverse dependency order
./scripts/stack.sh down

# Pull the exact pinned images
./scripts/stack.sh pull

# Stack logs
./scripts/stack.sh logs nextcloud

# Runtime/firewall/health verification
./scripts/stack.sh verify

# Root-only configuration and generated credentials
sudoedit /etc/server-infra/deploy.env
sudoedit /etc/server-infra/secrets.env

# WireGuard and firewall
sudo wg show
sudo ufw status verbose
sudo systemctl status server-infra-docker-firewall

# Monitoring timer and latest report
systemctl list-timers server-infra-health.timer
sudo tail -200 /var/log/server-infra/health.log

# Backup
./scripts/stack.sh backup

# Restore (destructive and explicit)
./scripts/stack.sh restore /srv/backups/server-infra-TIMESTAMP --confirm
```

Version upgrades are deliberate changes to `config/versions.env`. Review
upstream release notes, update tags and amd64 manifest digests together, render
all Compose projects, back up, then reconcile the affected stack.
