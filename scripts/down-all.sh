#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(proxy mollysocket audiobookshelf navidrome calibre jellyseerr jellyfin ha immich nextcloud)

project_name_for_stack() {
  local stack="$1"
  echo "${stack}_fresh"
}

for stack in "${stacks[@]}"; do
  if [[ ! -f "$stack/docker-compose.yml" ]]; then
    echo "Skipping missing stack directory: $stack"
    continue
  fi

  if [[ ! -f "$stack/.env" ]]; then
    echo "Skipping $stack because $stack/.env does not exist"
    continue
  fi

  echo "Stopping stack: $stack"
  (
    cd "$stack"
    docker compose --project-name "$(project_name_for_stack "$stack")" down
  )
done

echo "All stacks stopped."
