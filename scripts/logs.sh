#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

project_name_for_stack() {
  local stack="$1"
  echo "${stack}_fresh"
}

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <stack> [service]"
  echo "Stacks: proxy nextcloud immich ha jellyfin jellyseerr calibre navidrome audiobookshelf mollysocket adguard transmission sonarr radarr prowlarr flaresolverr bazarr tdarr recyclarr"
  exit 1
fi

stack="$1"
service="${2:-}"

if [[ ! -f "$stack/docker-compose.yml" ]]; then
  echo "Unknown stack: $stack"
  exit 1
fi

if [[ -n "$service" ]]; then
  (
    cd "$stack"
    docker compose --project-name "$(project_name_for_stack "$stack")" logs -f --tail=200 "$service"
  )
else
  (
    cd "$stack"
    docker compose --project-name "$(project_name_for_stack "$stack")" logs -f --tail=200
  )
fi
