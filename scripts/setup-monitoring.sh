#!/bin/bash

# Setup Monitoring & Automation
# Adds cron jobs for daily monitoring

set -e

echo "📊 Setting up monitoring and automation..."

# Add cron jobs
(crontab -l 2>/dev/null || true; cat << 'EOF'
# OpenClaw Home Server Monitoring & Automation

# Job 1: Daily Package Updates (2:00 AM)
0 2 * * * sudo apt update && sudo apt upgrade -y >> /var/log/openclaw/package-update.log 2>&1

# Job 2: Docker Maintenance (3:00 AM)
0 3 * * * /srv/server/scripts/docker-maintenance.sh >> /var/log/openclaw/docker-maint.log 2>&1

# Job 3: Caddy Certificate Check (Sun 4:00 AM)
0 4 * * 0 /srv/server/scripts/caddy-cert-monitor.sh >> /var/log/openclaw/caddy-cert.log 2>&1

# Job 4: Docker Image Updates (6:00 AM)
0 6 * * * /srv/server/scripts/check-docker-updates.sh >> /var/log/openclaw/docker-updates.log 2>&1

# Job 5: Home Assistant Status (7:00 AM)
0 7 * * * /srv/server/scripts/ha-integration.sh >> /var/log/openclaw/ha-status.log 2>&1

# Job 6: Media Library Status (8:00 AM)
0 8 * * * /srv/server/scripts/media-library-mgmt.sh >> /var/log/openclaw/media-maint.log 2>&1

# Job 7: Daily Monitoring Report (9:00 AM)
0 9 * * * /srv/server/scripts/generate-monitoring-report.sh >> /var/log/openclaw/monitoring.log 2>&1
EOF
) | sudo crontab -

echo "✅ Cron jobs installed"

# Create log directory
sudo mkdir -p /var/log/openclaw
sudo chmod 755 /var/log/openclaw

echo "✅ Log directory created"
echo ""
echo "Monitoring setup complete!"
echo ""
echo "Scheduled jobs:"
echo "  2:00 AM - Package updates"
echo "  3:00 AM - Docker maintenance"
echo "  4:00 AM (Sun) - Certificate check"
echo "  6:00 AM - Docker image update check"
echo "  7:00 AM - Home Assistant status"
echo "  8:00 AM - Media library status"
echo "  9:00 AM - Daily monitoring report"
