#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

stacks=(proxy nextcloud immich ha jellyfin jellyseerr calibre navidrome audiobookshelf invidious n8n mollysocket adguard)

has_key() {
  local key="$1"
  local file="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -q "^${key}=" "$file"
  else
    grep -qE "^${key}=" "$file"
  fi
}

sync_missing_keys() {
  local src="$1"
  local dst="$2"
  local added=0
  local line key

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"

    if ! has_key "$key" "$dst"; then
      echo "$line" >> "$dst"
      added=$((added + 1))
    fi
  done < "$src"

  if (( added > 0 )); then
    echo "Added $added missing keys to $dst from $src"
  fi
}

for stack in "${stacks[@]}"; do
  src="$stack/.env.example"
  dst="$stack/.env"

  if [[ ! -f "$src" ]]; then
    echo "Skipping $stack: missing $src"
    continue
  fi

  if [[ -f "$dst" ]]; then
    echo "Keeping existing $dst"
    sync_missing_keys "$src" "$dst"
    chmod 600 "$dst" 2>/dev/null || true
    continue
  fi

  cp "$src" "$dst"
  chmod 600 "$dst"
  echo "Created $dst"
done

echo "Review and edit all .env files before first deployment."
