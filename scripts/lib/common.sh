#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="${VERSION_FILE:-$REPO_ROOT/config/versions.env}"
DEPLOY_CONFIG="${DEPLOY_CONFIG:-/etc/server-infra/deploy.env}"
SECRETS_FILE="${SECRETS_FILE:-/etc/server-infra/secrets.env}"

CORE_STACKS=(nextcloud immich jellyfin seerr calibre audiobookshelf authelia gitea woodpecker proxy)
FULL_STACKS=(nextcloud immich jellyfin seerr calibre audiobookshelf authelia mollysocket media-vpn sonarr radarr lidarr flaresolverr bazarr tdarr recyclarr adguard gitea woodpecker proxy)
PUBLIC_SUBDOMAINS=(nc immich hometheater seerr calibre audiobookshelf auth)

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Run with sudo or as root."
}

load_environment() {
  [[ -r "$VERSION_FILE" ]] || die "Missing version manifest: $VERSION_FILE"
  [[ -r "$DEPLOY_CONFIG" ]] || die "Missing deployment config: $DEPLOY_CONFIG"
  set -a
  # shellcheck disable=SC1090
  source "$VERSION_FILE"
  # shellcheck disable=SC1090
  source "$DEPLOY_CONFIG"
  if [[ -r "$SECRETS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
  fi
  set +a
  DEPLOY_PROFILE="${DEPLOY_PROFILE:-full}"
  PUID="${PUID:-1000}"
  PGID="${PGID:-1000}"
  WG_PRIVATE_IP="${WG_ADDRESS%/*}"
  export DEPLOY_PROFILE PUID PGID WG_PRIVATE_IP
}

selected_stacks() {
  case "$DEPLOY_PROFILE" in
    core) printf '%s\n' "${CORE_STACKS[@]}" ;;
    full) printf '%s\n' "${FULL_STACKS[@]}" ;;
    *) die "DEPLOY_PROFILE must be core or full" ;;
  esac
}

public_hosts() {
  local prefix
  printf '%s\n' "$ROOT_DOMAIN"
  for prefix in "${PUBLIC_SUBDOMAINS[@]}"; do
    printf '%s.%s\n' "$prefix" "$ROOT_DOMAIN"
  done
  # Gitea is served on its own domain rather than a ROOT_DOMAIN subdomain.
  [[ -n "${GITEA_DOMAIN:-}" ]] && printf '%s\n' "$GITEA_DOMAIN"
}

compose() {
  local stack="$1"
  shift
  [[ -f "$REPO_ROOT/$stack/docker-compose.yml" ]] || die "Unknown stack: $stack"
  (
    cd "$REPO_ROOT/$stack"
    docker compose --project-name "server-$stack" "$@"
  )
}
