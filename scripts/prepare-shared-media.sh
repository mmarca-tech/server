#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SRV_ROOT="${SRV_ROOT:-/srv}"
MEDIA_ROOT="$SRV_ROOT/media"

shared_dirs=(
  "$MEDIA_ROOT"
  "$MEDIA_ROOT/movies"
  "$MEDIA_ROOT/series"
  "$MEDIA_ROOT/music"
  "$MEDIA_ROOT/audiobooks"
  "$MEDIA_ROOT/podcasts"
  "$MEDIA_ROOT/downloads"
  "$MEDIA_ROOT/downloads/incomplete"
)

ensure_legacy_link() {
  local legacy_path="$1"
  local target_path="$2"

  if [[ -L "$legacy_path" ]]; then
    return
  fi

  if [[ -d "$legacy_path" ]]; then
    if find "$legacy_path" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
      echo "Keeping legacy path with existing data: $legacy_path"
      echo "Move/copy this data into: $target_path"
      return
    fi

    sudo rmdir "$legacy_path" 2>/dev/null || true
  elif [[ -e "$legacy_path" ]]; then
    echo "Skipping legacy path (not a directory/link): $legacy_path"
    return
  fi

  if [[ ! -e "$legacy_path" ]]; then
    sudo ln -s "$target_path" "$legacy_path"
    sudo chown -h "$USER:$USER" "$legacy_path" 2>/dev/null || true
    echo "Linked legacy path: $legacy_path -> $target_path"
  fi
}

echo "Ensuring shared media directories exist under $MEDIA_ROOT"
sudo mkdir -p "${shared_dirs[@]}"
sudo chown -R "$USER:$USER" "$MEDIA_ROOT"
sudo find "$MEDIA_ROOT" -type d -exec chmod 755 {} \;
sudo find "$MEDIA_ROOT" -type f -exec chmod 644 {} \; 2>/dev/null || true

# Backward-compatibility links for old single-app storage paths.
ensure_legacy_link "$SRV_ROOT/navidrome/music" "$MEDIA_ROOT/music"
ensure_legacy_link "$SRV_ROOT/audiobookshelf/audiobooks" "$MEDIA_ROOT/audiobooks"
ensure_legacy_link "$SRV_ROOT/audiobookshelf/podcasts" "$MEDIA_ROOT/podcasts"

echo "Shared media directories are ready."
