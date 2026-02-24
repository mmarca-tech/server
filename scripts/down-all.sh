#!/usr/bin/env bash
set -euo pipefail

stacks=(proxy mollysocket calibre jellyseerr jellyfin ha immich nextcloud)

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
    docker compose --project-name "$stack" down
  )
done

echo "All stacks stopped."
