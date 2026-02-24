#!/usr/bin/env bash
set -euo pipefail

stacks=(proxy nextcloud immich ha jellyfin jellyseerr calibre mollysocket)

for stack in "${stacks[@]}"; do
  if [[ ! -f "$stack/.env" ]]; then
    echo "Missing $stack/.env"
    echo "Run ./scripts/init-env.sh before pulling stacks."
    exit 1
  fi

  echo "Pulling images for stack: $stack"
  (
    cd "$stack"
    docker compose --project-name "$stack" pull
  )
done

echo "Pull complete for all stacks."
