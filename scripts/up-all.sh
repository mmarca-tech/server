#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(nextcloud immich ha jellyfin jellyseerr calibre navidrome audiobookshelf mollysocket proxy)

project_name_for_stack() {
  local stack="$1"
  echo "${stack}_fresh"
}

ensure_shared_media_dirs() {
  local required=(
    /srv/media/music
    /srv/media/audiobooks
    /srv/media/podcasts
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

for stack in "${stacks[@]}"; do
  if [[ ! -f "$stack/.env" ]]; then
    echo "Missing $stack/.env"
    echo "Run ./scripts/init-env.sh and fill all required values before deploy."
    exit 1
  fi

  echo "Starting stack: $stack"
  (
    cd "$stack"
    docker compose --project-name "$(project_name_for_stack "$stack")" up -d
  )
done

echo "All stacks started."
