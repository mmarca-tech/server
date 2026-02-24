#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(nextcloud immich ha jellyfin jellyseerr calibre mollysocket proxy)

for stack in "${stacks[@]}"; do
  if [[ ! -f "$stack/.env" ]]; then
    echo "Missing $stack/.env"
    echo "Run ./scripts/init-env.sh and fill all required values before deploy."
    exit 1
  fi

  echo "Starting stack: $stack"
  (
    cd "$stack"
    docker compose --project-name "$stack" up -d
  )
done

echo "All stacks started."
