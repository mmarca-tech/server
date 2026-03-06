#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(nextcloud immich ha jellyfin jellyseerr calibre navidrome audiobookshelf mollysocket adguard proxy transmission sonarr radarr prowlarr flaresolverr)
COMPOSE_WAIT_TIMEOUT="${COMPOSE_WAIT_TIMEOUT:-600}"
NEXTCLOUD_AUTO_FIX="${NEXTCLOUD_AUTO_FIX:-true}"
compose_wait_supported=false

project_name_for_stack() {
  local stack="$1"
  echo "${stack}_fresh"
}

ensure_shared_media_dirs() {
  local required=(
    /srv/media/music
    /srv/media/audiobooks
    /srv/media/podcasts
    /srv/media/movies
    /srv/media/series
    /srv/media/downloads
  )
  local missing=()
  local path

  for path in "${required[@]}"; do
    if [[ ! -d "$path" ]]; then
      missing+=("$path")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing shared media directory(s):"
    printf ' - %s\n' "${missing[@]}"
    echo "Run ./scripts/prepare-shared-media.sh (or ./scripts/bootstrap-host.sh) first."
    exit 1
  fi
}

if ! docker network inspect proxy >/dev/null 2>&1; then
  echo "Creating external Docker network: proxy"
  docker network create proxy >/dev/null
else
  echo "Docker network already exists: proxy"
fi

ensure_shared_media_dirs

if docker compose up --help 2>/dev/null | grep -q -- '--wait'; then
  compose_wait_supported=true
else
  echo "Warning: this Docker Compose version does not support --wait; startup will not block on health checks."
fi

for stack in "${stacks[@]}"; do
  echo "Starting stack: $stack"
  (
    cd "$stack"
    if [[ "$compose_wait_supported" == "true" ]]; then
      docker compose \
        --project-name "$(project_name_for_stack "$stack")" \
        up -d --wait --wait-timeout "$COMPOSE_WAIT_TIMEOUT"
    else
      docker compose --project-name "$(project_name_for_stack "$stack")" up -d
    fi
  )

  if [[ "$stack" == "nextcloud" && "$NEXTCLOUD_AUTO_FIX" == "true" ]]; then
    echo "Applying Nextcloud proxy/HTTPS defaults"
    PROJECT_NAME="$(project_name_for_stack "$stack")" "$ROOT_DIR/scripts/nextcloud-fix.sh"
  fi
done

echo "All stacks started."
