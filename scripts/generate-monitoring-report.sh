#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

echo "=== Daily Monitoring Report ==="
echo "Date: $(date)"
echo "Host: $(hostname)"
echo ""

echo "--- System ---"
uptime
echo "Load: $(cat /proc/loadavg)"
echo "Memory: $(free -h | awk 'NR==2{print $3 " used / " $2 " total"}')"
echo ""

echo "--- Disk ---"
df -h /srv / 2>/dev/null | head -5
echo ""

echo "--- Docker ---"
echo "Running containers: $(docker ps -q | wc -l)"
echo "Total images: $(docker images -q | wc -l)"
docker ps --format "  {{.Names}}: {{.Status}}" | sort
echo ""

echo "--- Recent Docker restarts (last 24h) ---"
docker ps -a --format '{{.Names}} {{.Status}}' | grep -v "Up" | grep -v "Created" || echo "  None"
echo ""

echo "=== End of Report ==="
