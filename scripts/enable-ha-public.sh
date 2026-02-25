#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HA_CONFIG_FILE="${HA_CONFIG_FILE:-/srv/homeassistant/config/configuration.yaml}"
TRUSTED_PROXY_CIDR="${TRUSTED_PROXY_CIDR:-172.16.0.0/12}"
HA_STACK_DIR="${HA_STACK_DIR:-$ROOT_DIR/ha}"
HA_PROJECT_NAME="${HA_PROJECT_NAME:-ha_fresh}"
PROXY_STACK_DIR="${PROXY_STACK_DIR:-$ROOT_DIR/proxy}"
PROXY_PROJECT_NAME="${PROXY_PROJECT_NAME:-proxy_fresh}"
RESTART_STACKS="${RESTART_STACKS:-true}"

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "sudo is required when running as non-root."
  exit 1
fi

as_root() {
  if [[ -n "$SUDO" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

ensure_file() {
  local f="$1"
  local parent
  parent="$(dirname "$f")"
  as_root mkdir -p "$parent"
  if ! as_root test -f "$f"; then
    as_root touch "$f"
  fi
}

insert_after_first_match() {
  local file="$1"
  local pattern="$2"
  local line_to_insert="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v p="$pattern" -v add="$line_to_insert" '
    BEGIN { inserted=0 }
    {
      print $0
      if (!inserted && $0 ~ p) {
        print add
        inserted=1
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

add_ha_http_proxy_config() {
  local tmp_file
  tmp_file="$(mktemp)"

  as_root cat "$HA_CONFIG_FILE" > "$tmp_file"

  if ! grep -Eq '^http:[[:space:]]*$' "$tmp_file"; then
    {
      echo
      echo "http:"
      echo "  use_x_forwarded_for: true"
      echo "  trusted_proxies:"
      echo "    - ${TRUSTED_PROXY_CIDR}"
    } >> "$tmp_file"
  else
    if grep -Eq '^[[:space:]]*use_x_forwarded_for:' "$tmp_file"; then
      sed -i -E 's/^[[:space:]]*use_x_forwarded_for:.*/  use_x_forwarded_for: true/' "$tmp_file"
    else
      insert_after_first_match "$tmp_file" '^http:[[:space:]]*$' '  use_x_forwarded_for: true'
    fi

    if ! grep -Eq '^[[:space:]]*trusted_proxies:[[:space:]]*$' "$tmp_file"; then
      insert_after_first_match "$tmp_file" '^[[:space:]]*use_x_forwarded_for:[[:space:]]*true[[:space:]]*$' '  trusted_proxies:'
    fi

    if ! grep -Fxq "    - ${TRUSTED_PROXY_CIDR}" "$tmp_file"; then
      insert_after_first_match "$tmp_file" '^[[:space:]]*trusted_proxies:[[:space:]]*$' "    - ${TRUSTED_PROXY_CIDR}"
    fi
  fi

  as_root cp "$HA_CONFIG_FILE" "${HA_CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  as_root cp "$tmp_file" "$HA_CONFIG_FILE"
  rm -f "$tmp_file"
}

enable_ha_caddy_route() {
  local caddyfile="$ROOT_DIR/proxy/Caddyfile"
  local tmp_file
  tmp_file="$(mktemp)"

  awk '
    BEGIN { in_ha=0 }
    /^ha\.\{\$ROOT_DOMAIN\}[[:space:]]*\{/ { print; in_ha=1; next }
    in_ha && /^[[:space:]]*reverse_proxy[[:space:]]+host\.docker\.internal:8123[[:space:]]*$/ { print; next }
    in_ha && /^\}[[:space:]]*$/ { print; in_ha=0; next }

    /^# ha\.\{\$ROOT_DOMAIN\}[[:space:]]*\{/ { sub(/^# /, ""); print; in_ha=1; next }
    in_ha && /^#   reverse_proxy host\.docker\.internal:8123[[:space:]]*$/ { sub(/^# /, ""); print; next }
    in_ha && /^# \}[[:space:]]*$/ { sub(/^# /, ""); print; in_ha=0; next }

    { print }
  ' "$caddyfile" > "$tmp_file"

  cp "$caddyfile" "${caddyfile}.bak.$(date +%Y%m%d%H%M%S)"
  mv "$tmp_file" "$caddyfile"
}

echo "Configuring Home Assistant proxy trust in $HA_CONFIG_FILE"
ensure_file "$HA_CONFIG_FILE"
add_ha_http_proxy_config

echo "Enabling Home Assistant Caddy route in proxy/Caddyfile"
enable_ha_caddy_route

if [[ "$RESTART_STACKS" == "true" ]]; then
  echo "Restarting Home Assistant container"
  (
    cd "$HA_STACK_DIR"
    as_root docker compose --project-name "$HA_PROJECT_NAME" restart homeassistant
  )

  echo "Reloading proxy stack"
  (
    cd "$PROXY_STACK_DIR"
    as_root docker compose --project-name "$PROXY_PROJECT_NAME" up -d
  )
fi

echo
echo "Home Assistant public route setup applied."
echo "Manual steps still required:"
echo " - Ensure router forwards only TCP 80/443 to this host."
echo " - Create DNS A record: ha.<your-domain> -> your WAN IP."
echo " - Test https://ha.<your-domain> from an external network."
