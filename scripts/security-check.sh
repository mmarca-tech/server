#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass_count=0
warn_count=0
fail_count=0

pass() {
  echo "[PASS] $1"
  pass_count=$((pass_count + 1))
}

warn() {
  echo "[WARN] $1"
  warn_count=$((warn_count + 1))
}

fail() {
  echo "[FAIL] $1"
  fail_count=$((fail_count + 1))
}

run_with_optional_sudo() {
  if sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
  else
    "$@"
  fi
}

echo "Running security checks in $ROOT_DIR"

if rg -q -F 'claw.{$ROOT_DOMAIN}' proxy/Caddyfile; then
  fail "OpenClaw public route found in proxy/Caddyfile"
else
  pass "No OpenClaw route in proxy/Caddyfile"
fi

if rg -q '^\(secure_headers\)' proxy/Caddyfile && rg -q 'Strict-Transport-Security' proxy/Caddyfile; then
  pass "Caddy secure headers policy is present"
else
  fail "Caddy secure headers policy is missing"
fi

compose_mutable="$(rg -n 'image:.*:(latest|release|stable)\\b' */docker-compose.yml || true)"
if [[ -n "$compose_mutable" ]]; then
  fail "Mutable image tags found in compose files:\n$compose_mutable"
else
  pass "Compose files do not use latest/release/stable image tags"
fi

env_mutable="$(rg -n '^[A-Z0-9_]+_IMAGE=.*:(latest|release|stable)\\b' */.env */.env.example 2>/dev/null || true)"
if [[ -n "$env_mutable" ]]; then
  fail "Mutable image tags found in env files:\n$env_mutable"
else
  pass "Env image variables are pinned away from latest/release/stable"
fi

non_proxy_port_pubs="$(rg -n '^\s+ports:\s*$' nextcloud/docker-compose.yml immich/docker-compose.yml ha/docker-compose.yml jellyfin/docker-compose.yml jellyseerr/docker-compose.yml calibre/docker-compose.yml mollysocket/docker-compose.yml || true)"
if [[ -n "$non_proxy_port_pubs" ]]; then
  fail "Non-proxy stacks publish host ports:\n$non_proxy_port_pubs"
else
  pass "Only proxy stack publishes host ports"
fi

env_perm_issues=()
while IFS= read -r env_file; do
  [[ -z "$env_file" ]] && continue
  mode="$(stat -c '%a' "$env_file")"
  if ((10#$mode > 600)); then
    env_perm_issues+=("$env_file ($mode)")
  fi
done < <(find . -mindepth 2 -maxdepth 2 -type f -name '.env' | sort)

if (( ${#env_perm_issues[@]} > 0 )); then
  fail "Insecure .env permissions found: ${env_perm_issues[*]}"
else
  pass "All stack .env files are permissioned at 600 or stricter"
fi

required_srv_dirs=(
  /srv/proxy
  /srv/nextcloud
  /srv/immich
  /srv/jellyfin
  /srv/jellyseerr
  /srv/calibre
  /srv/mollysocket
  /srv/homeassistant
  /srv/databases
  /srv/backups
)
missing_srv_dirs=()
for d in "${required_srv_dirs[@]}"; do
  if [[ ! -d "$d" ]]; then
    missing_srv_dirs+=("$d")
  fi
done

if (( ${#missing_srv_dirs[@]} > 0 )); then
  warn "Missing expected /srv directories: ${missing_srv_dirs[*]}"
else
  pass "Expected /srv directory layout exists"
fi

if command -v ufw >/dev/null 2>&1; then
  if ufw_status="$(run_with_optional_sudo ufw status 2>/dev/null)"; then
    if echo "$ufw_status" | rg -q '^Status: active'; then
      pass "UFW is active"

      if echo "$ufw_status" | rg -q '80/tcp\s+ALLOW'; then
        pass "UFW allows 80/tcp"
      else
        warn "UFW rule for 80/tcp not found"
      fi

      if echo "$ufw_status" | rg -q '443/tcp\s+ALLOW'; then
        pass "UFW allows 443/tcp"
      else
        warn "UFW rule for 443/tcp not found"
      fi

      if echo "$ufw_status" | rg -q '18789/tcp\s+DENY'; then
        pass "UFW denies 18789/tcp"
      else
        fail "UFW deny rule for 18789/tcp not found"
      fi

      if echo "$ufw_status" | rg -q '18790/tcp\s+DENY'; then
        pass "UFW denies 18790/tcp"
      else
        fail "UFW deny rule for 18790/tcp not found"
      fi
    else
      fail "UFW is installed but not active"
    fi
  else
    warn "Could not read UFW status (try running this script with sudo)"
  fi
else
  warn "UFW is not installed"
fi

if command -v ss >/dev/null 2>&1; then
  openclaw_ports="$(ss -ltnH '( sport = :18789 or sport = :18790 )' 2>/dev/null || true)"
  if [[ -z "$openclaw_ports" ]]; then
    pass "No listeners on OpenClaw network ports (18789/18790)"
  elif echo "$openclaw_ports" | rg -q '0\.0\.0\.0:1878[90]|\[::\]:1878[90]'; then
    fail "OpenClaw port is listening on public interfaces:\n$openclaw_ports"
  else
    warn "OpenClaw ports are listening but not on wildcard interfaces:\n$openclaw_ports"
  fi

  docker_remote_api="$(ss -ltnH '( sport = :2375 or sport = :2376 )' 2>/dev/null || true)"
  if [[ -n "$docker_remote_api" ]]; then
    fail "Docker remote API appears exposed:\n$docker_remote_api"
  else
    pass "Docker remote API ports (2375/2376) are not listening"
  fi
else
  warn "Could not run socket checks because ss is unavailable"
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files 2>/dev/null | rg -q '^openclaw-gateway\.service'; then
    if run_with_optional_sudo systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
      pass "openclaw-gateway service is active"
    else
      warn "openclaw-gateway service is installed but not active"
    fi
  else
    warn "openclaw-gateway service is not installed"
  fi

  if run_with_optional_sudo systemctl is-active --quiet fail2ban 2>/dev/null; then
    pass "fail2ban service is active"
  else
    warn "fail2ban service is not active"
  fi

  if run_with_optional_sudo systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
    pass "unattended-upgrades is enabled"
  else
    warn "unattended-upgrades is not enabled"
  fi
else
  warn "systemctl is unavailable; service-level checks skipped"
fi

echo
echo "Summary: $pass_count passed, $warn_count warnings, $fail_count failures"

if (( fail_count > 0 )); then
  exit 1
fi
