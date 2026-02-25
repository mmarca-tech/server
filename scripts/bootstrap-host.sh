#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SRV_ROOT="${SRV_ROOT:-/srv}"

directories=(
  "$SRV_ROOT/proxy"
  "$SRV_ROOT/proxy/caddy-data"
  "$SRV_ROOT/proxy/caddy-config"
  "$SRV_ROOT/nextcloud"
  "$SRV_ROOT/nextcloud/html"
  "$SRV_ROOT/nextcloud/data"
  "$SRV_ROOT/immich"
  "$SRV_ROOT/immich/library"
  "$SRV_ROOT/immich/model-cache"
  "$SRV_ROOT/jellyfin"
  "$SRV_ROOT/jellyfin/config"
  "$SRV_ROOT/jellyfin/cache"
  "$SRV_ROOT/jellyfin/media"
  "$SRV_ROOT/jellyseerr"
  "$SRV_ROOT/jellyseerr/config"
  "$SRV_ROOT/calibre"
  "$SRV_ROOT/calibre/config"
  "$SRV_ROOT/calibre/library"
  "$SRV_ROOT/navidrome"
  "$SRV_ROOT/navidrome/data"
  "$SRV_ROOT/navidrome/music"
  "$SRV_ROOT/audiobookshelf"
  "$SRV_ROOT/audiobookshelf/config"
  "$SRV_ROOT/audiobookshelf/metadata"
  "$SRV_ROOT/audiobookshelf/audiobooks"
  "$SRV_ROOT/audiobookshelf/podcasts"
  "$SRV_ROOT/mollysocket"
  "$SRV_ROOT/mollysocket/data"
  "$SRV_ROOT/homeassistant"
  "$SRV_ROOT/homeassistant/config"
  "$SRV_ROOT/databases"
  "$SRV_ROOT/databases/nextcloud-mariadb"
  "$SRV_ROOT/databases/immich-postgres"
  "$SRV_ROOT/backups"
)

echo "Creating app data directories under $SRV_ROOT"
sudo mkdir -p "${directories[@]}"
sudo chown -R "$USER:$USER" "${directories[@]}"

if ! docker network inspect proxy >/dev/null 2>&1; then
  echo "Creating external Docker network: proxy"
  docker network create proxy >/dev/null
else
  echo "Docker network already exists: proxy"
fi

echo "Host bootstrap complete."
