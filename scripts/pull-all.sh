#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(proxy nextcloud immich ha jellyfin jellyseerr calibre navidrome audiobookshelf mollysocket)

project_name_for_stack() {
  local stack="$1"
  echo "${stack}_fresh"
}

for stack in "${stacks[@]}"; do
  if [[ ! -f "$stack/.env" ]]; then
    echo "Missing $stack/.env"
    echo "Run ./scripts/init-env.sh before pulling stacks."
    exit 1
  fi

  echo "Pulling images for stack: $stack"
  (
    cd "$stack"
    docker compose --project-name "$(project_name_for_stack "$stack")" pull
  )
done

echo "Pull complete for all stacks."
