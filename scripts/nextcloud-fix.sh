#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="${STACK_DIR:-$ROOT_DIR/nextcloud}"
ENV_FILE="${ENV_FILE:-$STACK_DIR/.env}"
PROJECT_NAME="${PROJECT_NAME:-nextcloud_fresh}"

include_expensive=false

usage() {
  cat <<'EOF'
Usage:
  ./scripts/nextcloud-fix.sh [--include-expensive]

Description:
  Applies Nextcloud proxy/HTTPS/security-related system config and maintenance window.
  Optionally runs expensive repair tasks for mimetypes and missing DB indices.

Options:
  --include-expensive  Also run:
                       - occ maintenance:repair --include-expensive
                       - occ db:add-missing-indices
  -h, --help           Show this help.
EOF
}

while (($# > 0)); do
  case "$1" in
    --include-expensive)
      include_expensive=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -f "$STACK_DIR/docker-compose.yml" ]]; then
  echo "Missing compose file: $STACK_DIR/docker-compose.yml" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

trusted_domains_raw="${NEXTCLOUD_TRUSTED_DOMAINS:-}"
if [[ -z "$trusted_domains_raw" ]]; then
  echo "NEXTCLOUD_TRUSTED_DOMAINS is not set in $ENV_FILE" >&2
  exit 1
fi

# first trusted domain is used as overwrite host default
trusted_domains_primary="${trusted_domains_raw%%,*}"
trusted_domains_primary="${trusted_domains_primary%% *}"

overwrite_protocol="${NEXTCLOUD_OVERWRITE_PROTOCOL:-https}"
overwrite_host="${NEXTCLOUD_OVERWRITE_HOST:-$trusted_domains_primary}"
overwrite_cli_url="${NEXTCLOUD_OVERWRITE_CLI_URL:-${overwrite_protocol}://${overwrite_host}}"
trusted_proxies_raw="${NEXTCLOUD_TRUSTED_PROXIES:-172.16.0.0/12}"
forward_for_header="${NEXTCLOUD_FORWARD_FOR_HEADER:-HTTP_X_FORWARDED_FOR}"
maintenance_window_start="${NEXTCLOUD_MAINTENANCE_WINDOW_START:-2}"

container_exec() {
  (
    cd "$STACK_DIR"
    docker compose --project-name "$PROJECT_NAME" exec -T "$@"
  )
}

detect_occ_path() {
  local candidate

  for candidate in /var/www/html/occ /usr/src/nextcloud/occ; do
    if container_exec nextcloud test -f "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

occ() {
  (
    cd "$STACK_DIR"
    docker compose --project-name "$PROJECT_NAME" exec -T -u www-data nextcloud php "$occ_path" "$@"
  )
}

container_id="$(
  cd "$STACK_DIR"
  docker compose --project-name "$PROJECT_NAME" ps -q nextcloud 2>/dev/null || true
)"
if [[ -z "$container_id" ]]; then
  echo "Nextcloud container is not running for project: $PROJECT_NAME" >&2
  echo "Start it first, then rerun this script." >&2
  exit 1
fi

occ_path="$(detect_occ_path || true)"
if [[ -z "$occ_path" ]]; then
  echo "Could not find occ inside the Nextcloud container." >&2
  echo "Checked: /var/www/html/occ and /usr/src/nextcloud/occ" >&2
  echo "Inspect the container layout with:" >&2
  echo "  docker compose --project-name \"$PROJECT_NAME\" exec -T nextcloud sh -lc 'ls -l /var/www/html /usr/src/nextcloud 2>/dev/null'" >&2
  exit 1
fi

echo "Applying Nextcloud proxy/HTTPS config via occ"

# reset and set trusted proxies list
occ config:system:delete trusted_proxies >/dev/null 2>&1 || true
i=0
IFS=', ' read -r -a trusted_proxy_items <<<"$trusted_proxies_raw"
for proxy in "${trusted_proxy_items[@]}"; do
  [[ -z "$proxy" ]] && continue
  occ config:system:set trusted_proxies "$i" --value="$proxy"
  i=$((i + 1))
done

# reset and set forwarded_for_headers list
occ config:system:delete forwarded_for_headers >/dev/null 2>&1 || true
occ config:system:set forwarded_for_headers 0 --value="$forward_for_header"

occ config:system:set overwriteprotocol --value="$overwrite_protocol"
occ config:system:set overwritehost --value="$overwrite_host"
occ config:system:set overwrite.cli.url --value="$overwrite_cli_url"
occ config:system:set maintenance_window_start --type=integer --value="$maintenance_window_start"

if [[ "$include_expensive" == true ]]; then
  echo "Running expensive Nextcloud maintenance tasks"
  occ maintenance:repair --include-expensive
  occ db:add-missing-indices
fi

echo "Done."
