#!/bin/bash

# Start All Services
# Brings up all Docker services in correct order

set -e

cd /srv/server

services=(
    "proxy"
    "nextcloud"
    "immich"
    "jellyfin"
    "jellyseerr"
    "navidrome"
    "calibre"
    "audiobookshelf"
    "ha"
    "adguard"
    "transmission"
    "mollysocket"
    "sonarr"
    "radarr"
    "prowlarr"
    "flaresolverr"
    "bazarr"
    "tdarr"
    "recyclarr"
)

echo "🚀 Starting all services..."
echo ""

for service in "${services[@]}"; do
    if [ -d "$service" ]; then
        echo "Starting $service..."
        cd "$service"
        docker compose up -d
        cd ..
        sleep 2
    fi
done

echo ""
echo "✅ All services started"
echo ""
echo "Checking status..."
docker ps -a --format "table {{.Names}}\t{{.Status}}"
