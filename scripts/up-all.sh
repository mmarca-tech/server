#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(nextcloud immich ha jellyfin jellyseerr calibre mollysocket proxy)

project_name_for_stack() {
  local stack="$1"
  if [[ "$stack" == "nextcloud" ]]; then
    echo "nextcloud_fresh"
  else
    echo "$stack"
  fi
}

if ! docker network inspect proxy >/dev/null 2>&1; then
  echo "Creating external Docker network: proxy"
  docker network create proxy >/dev/null
else
  echo "Docker network already exists: proxy"
fi

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
