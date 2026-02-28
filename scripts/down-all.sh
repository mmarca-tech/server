#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(proxy adguard mollysocket audiobookshelf navidrome calibre jellyseerr jellyfin ha immich nextcloud)

project_name_for_stack() {
  local stack="$1"
  echo "${stack}_fresh"
}

legacy_project_name_for_stack() {
  local stack="$1"
  echo "$stack"
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

  for project_name in "$(project_name_for_stack "$stack")" "$(legacy_project_name_for_stack "$stack")"; do
    echo "Stopping stack: $stack (project: $project_name)"
    (
      cd "$stack"
      docker compose --project-name "$project_name" down --remove-orphans
    )
  done
done

echo "All stacks stopped."
