#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

echo "=== Docker Maintenance ==="
echo "Date: $(date)"
echo ""

# Disk before
srv_path="/srv/docker"
[[ -d "$srv_path" ]] || srv_path="/var/lib/docker"
before=$(df -h "$srv_path" | awk 'NR==2{print $3 " used / " $2 " total (" $5 ")"}')

echo "--- Pruning dangling images ---"
docker image prune -f

echo ""
echo "--- Pruning stopped containers ---"
docker container prune -f

echo ""
echo "--- Pruning unused volumes ---"
docker volume prune -f

echo ""
echo "--- Pruning unused networks ---"
docker network prune -f

after=$(df -h "$srv_path" | awk 'NR==2{print $3 " used / " $2 " total (" $5 ")"}')

echo ""
echo "=== Summary ==="
echo "Disk before: $before"
echo "Disk after:  $after"
echo "Running containers: $(docker ps -q | wc -l)"
echo "Total images: $(docker images -q | wc -l)"
