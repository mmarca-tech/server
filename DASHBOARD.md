# 📊 Visual Dashboard Guide

Real-time monitoring dashboard for your home server. View Docker containers, disk usage, memory, system uptime, and service status at a glance.

---

## 🚀 Quick Start

### View Once

```bash
/srv/openclaw/scripts/dashboard-visual.sh
```

Shows a single snapshot of your system status.

### Live Updates (Recommended)

```bash
watch -n 5 /srv/openclaw/scripts/dashboard-visual.sh
```

Refreshes every 5 seconds. Press `q` to exit.

---

## 📈 What's Displayed

### DOCKER CONTAINERS
- **Running count** — How many containers are up / total
- **Service list** with:
  - ✓ Green checkmark = running
  - ✗ Red X = stopped
  - Uptime for each service

### DISK USAGE
- **/ (Root)** — System partition usage
- **/srv (Media)** — Media storage usage
- Visual progress bars:
  - 🟢 Green = healthy (<80%)
  - 🔴 Red = warning (≥80%)

### SYSTEM INFO
- **Uptime** — How long since last reboot
- **Load** — CPU load average (1m, 5m, 15m)
- **Memory** — RAM usage percentage with progress bar

---

## 🔧 Script Location

```
/srv/openclaw/scripts/dashboard-visual.sh
```

### How It Works

1. **Queries Docker** — `docker ps` for container status
2. **Reads filesystem** — `df` for disk usage
3. **Gets system info** — `uptime`, `free` for memory
4. **Formats output** — Colors, progress bars, checkmarks

### Supported Containers

Automatically detects:
- jellyfin
- immich-server
- navidrome
- nextcloud
- caddy
- adguard
- homeassistant
- calibre-web
- jellyseerr
- audiobookshelf

---

## 🎨 Features

### Color Coding

- **🟢 Green** — Running/healthy/online
- **🔴 Red** — Stopped/critical/high usage (>80%)
- **🟡 Yellow** — Warning/caution states
- **🔵 Blue** — Headings/sections
- **🔵 Cyan** — Status values

### Progress Bars

Visual representation of usage:

```
/ (Root):     ████████░░░░░░░░░░░░░  48%
/srv (Media): ███████░░░░░░░░░░░░░░░  39%
Memory:       ████░░░░░░░░░░░░░░░░░░  23%
```

Bars fill left-to-right. Green = normal, red = critical.

### Status Indicators

- **✓** (checkmark) = Container is running
- **✗** (X) = Container is stopped
- **●** (dot) = Service indicator

---

## 📱 Integration Examples

### Auto-Refresh in Terminal

```bash
# Every 5 seconds
watch -n 5 /srv/openclaw/scripts/dashboard-visual.sh

# Every 30 seconds
watch -n 30 /srv/openclaw/scripts/dashboard-visual.sh
```

### Continuous Loop

```bash
while true; do
    clear
    /srv/openclaw/scripts/dashboard-visual.sh
    sleep 5
done
```

### Cron Job (Periodic Snapshots)

```bash
# Log dashboard every hour
0 * * * * /srv/openclaw/scripts/dashboard-visual.sh >> /tmp/dashboard-snapshots.log 2>&1
```

### Alias for Quick Access

```bash
# Add to ~/.bashrc or ~/.zshrc
alias dash="watch -n 5 /srv/openclaw/scripts/dashboard-visual.sh"
alias dashonce="/srv/openclaw/scripts/dashboard-visual.sh"

# Then use:
dash      # live updates
dashonce  # single snapshot
```

---

## 🔍 Reading the Output

### Example Output

```
════════════════════════════════════════════════════════════════
            🖥️  HOME SERVER STATUS DASHBOARD
                2026-03-05 12:02:41
════════════════════════════════════════════════════════════════

DOCKER CONTAINERS
─────────────────────────────────────────
Running: 16 / 16

Services:
  ✓ jellyfin             7 days
  ✓ immich-server        4 days
  ✓ navidrome            7 days
  ✓ nextcloud            5 days
  ✓ caddy                5 days
  ✓ adguard              5 days
  ✓ homeassistant        5 days
  ✓ calibre-web          7 days
  ✓ jellyseerr           7 days
  ✓ audiobookshelf       7 days

DISK USAGE
─────────────────────────────────────────
  / (Root):     █████████░░░░░░░░░░░  48%
  /srv (Media): ███████░░░░░░░░░░░░░  39%

SYSTEM INFO
─────────────────────────────────────────
  Uptime:  up 25 minutes
  Load:    1.34, 1.29, 1.01
  Memory:  ████░░░░░░░░░░░░░░░░  23%
```

**Interpretation:**
- All 16 containers running ✓
- Root disk 48% full (healthy)
- /srv media 39% full (plenty of space)
- System load normal
- Memory usage 23% (low)

---

## ⚠️ Troubleshooting

### No output / blank screen

```bash
# Check if TERM is set
echo $TERM

# Run with explicit TERM
TERM=xterm /srv/openclaw/scripts/dashboard-visual.sh
```

### Colors not showing

```bash
# Force color output
/srv/openclaw/scripts/dashboard-visual.sh | cat
```

### Service not showing in list

The script searches by container name. If a service isn't listed:

```bash
# Check running containers
docker ps -a --format "{{.Names}}"

# Add missing service name to the script (near line 30)
# Edit: /srv/openclaw/scripts/dashboard-visual.sh
```

### "watch" command not found

```bash
# Install it
sudo apt install procps

# Or use manual loop instead
while true; do clear; /srv/openclaw/scripts/dashboard-visual.sh; sleep 5; done
```

---

## 🛠️ Customization

### Adding a New Service

Edit `/srv/openclaw/scripts/dashboard-visual.sh`:

Find this line:
```bash
for service in jellyfin immich-server navidrome nextcloud caddy adguard homeassistant calibre-web jellyseerr audiobookshelf; do
```

Add your service name to the list:
```bash
for service in jellyfin immich-server navidrome nextcloud caddy adguard homeassistant calibre-web jellyseerr audiobookshelf YOURSERVICE; do
```

Then commit:
```bash
/srv/server/git-auto-commit.sh "Add YOURSERVICE to dashboard"
```

### Changing Refresh Rate

```bash
# 2 seconds (fast)
watch -n 2 /srv/openclaw/scripts/dashboard-visual.sh

# 10 seconds (slower)
watch -n 10 /srv/openclaw/scripts/dashboard-visual.sh
```

### Adjusting Color Thresholds

Edit the script to change when colors turn red. For example, change disk warning from 80% to 75%:

```bash
# Find this line:
if [ "$ROOT_USAGE" -lt 80 ]; then

# Change to:
if [ "$ROOT_USAGE" -lt 75 ]; then
```

---

## 📊 Monitoring Strategy

### Daily Routine

```bash
# Start of day
watch -n 5 /srv/openclaw/scripts/dashboard-visual.sh

# Check for:
# - Any containers down?
# - Disk usage growing?
# - Memory under control?
```

### Weekly Review

```bash
# Check performance trends
/srv/openclaw/scripts/generate-monitoring-report.sh
cat /srv/server/MONITORING_REPORTS/$(date +%Y-%m-%d).md
```

### Alerts

The dashboard is visual feedback. For **automated alerts**, use the monitoring jobs:
- Docker maintenance (3:00 AM)
- Disk space checks (included in daily reports)
- Container error logs (checked automatically)

---

## 🔗 Related Documentation

- [INFRASTRUCTURE.md](INFRASTRUCTURE.md) — System architecture & overview
- [SERVICES.md](SERVICES.md) — Individual service docs
- [OPENCLAW_AUTOMATION.md](OPENCLAW_AUTOMATION.md) — Automation & reporting
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Fast commands

---

## 📝 Version History

- **2026-03-05** — Initial dashboard created
  - Fixed nextcloud detection issue
  - Added 10-service support
  - Color-coded status indicators
  - Progress bars for disk & memory

