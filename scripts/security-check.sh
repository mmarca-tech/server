#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LAN_IP="${LAN_IP:-192.168.1.20}"
LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"

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
  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
  else
    "$@"
  fi
}

resolve_ufw() {
  if command -v ufw >/dev/null 2>&1; then
    command -v ufw
    return 0
  fi
  if [[ -x /usr/sbin/ufw ]]; then
    echo "/usr/sbin/ufw"
    return 0
  fi
  return 1
}

echo "Running security checks in $ROOT_DIR"

if grep -Fq 'claw.{$ROOT_DOMAIN}' proxy/Caddyfile; then
  fail "OpenClaw public route found in proxy/Caddyfile"
else
  pass "No OpenClaw route in proxy/Caddyfile"
fi

if grep -Eq '^\(secure_headers\)' proxy/Caddyfile && grep -Fq 'Strict-Transport-Security' proxy/Caddyfile; then
  pass "Caddy secure headers policy is present"
else
  fail "Caddy secure headers policy is missing"
fi

if grep -Eq '^ha\.\{\$ROOT_DOMAIN\}[[:space:]]*\{' proxy/Caddyfile; then
  ha_cfg="/srv/homeassistant/config/configuration.yaml"
  if [[ ! -f "$ha_cfg" ]]; then
    fail "Home Assistant public route is enabled but $ha_cfg is missing"
  else
    if grep -Eq '^[[:space:]]*use_x_forwarded_for:[[:space:]]*true[[:space:]]*$' "$ha_cfg"; then
      pass "Home Assistant use_x_forwarded_for is enabled"
    else
      fail "Home Assistant use_x_forwarded_for is not enabled"
    fi

    if grep -Eq '^[[:space:]]*trusted_proxies:[[:space:]]*$' "$ha_cfg" && \
       grep -Eq '^[[:space:]]*-[[:space:]]*172\.16\.0\.0/12[[:space:]]*$' "$ha_cfg"; then
      pass "Home Assistant trusted_proxies includes 172.16.0.0/12"
    else
      fail "Home Assistant trusted_proxies is missing 172.16.0.0/12 while public route is enabled"
    fi
  fi
else
  warn "Home Assistant public Caddy route is not enabled; proxy trust checks skipped"
fi

compose_mutable="$(grep -nHE 'image:.*:(latest|release|stable)\b' */docker-compose.yml 2>/dev/null || true)"
if [[ -n "$compose_mutable" ]]; then
  fail "Mutable image tags found in compose files:\n$compose_mutable"
else
  pass "Compose files do not use latest/release/stable image tags"
fi

env_mutable="$(grep -nHE '^[A-Z0-9_]+_IMAGE=.*:(latest|release|stable)\b' */.env */.env.example 2>/dev/null || true)"
if [[ -n "$env_mutable" ]]; then
  fail "Mutable image tags found in env files:\n$env_mutable"
else
  pass "Env image variables are pinned away from latest/release/stable"
fi

non_proxy_port_pubs="$(grep -nHE '^[[:space:]]+ports:[[:space:]]*$' nextcloud/docker-compose.yml immich/docker-compose.yml ha/docker-compose.yml jellyfin/docker-compose.yml jellyseerr/docker-compose.yml calibre/docker-compose.yml navidrome/docker-compose.yml audiobookshelf/docker-compose.yml invidious/docker-compose.yml mollysocket/docker-compose.yml adguard/docker-compose.yml || true)"
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
  /srv/navidrome
  /srv/audiobookshelf
  /srv/invidious
  /srv/mollysocket
  /srv/adguard
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

if command -v ip >/dev/null 2>&1; then
  if ip -4 addr show 2>/dev/null | grep -Fq "$LAN_IP"; then
    pass "Host has expected LAN IP $LAN_IP"
  else
    warn "Host does not currently show expected LAN IP $LAN_IP"
  fi
else
  warn "ip command unavailable; LAN IP check skipped"
fi

if UFW_BIN="$(resolve_ufw 2>/dev/null)"; then
  if ufw_status="$(run_with_optional_sudo "$UFW_BIN" status 2>/dev/null)"; then
    if echo "$ufw_status" | grep -Eq '^Status: active'; then
      pass "UFW is active"

      if echo "$ufw_status" | grep -Eq '80/tcp[[:space:]]+ALLOW'; then
        pass "UFW allows 80/tcp"
      else
        warn "UFW rule for 80/tcp not found"
      fi

      if echo "$ufw_status" | grep -Eq '443/tcp[[:space:]]+ALLOW'; then
        pass "UFW allows 443/tcp"
      else
        warn "UFW rule for 443/tcp not found"
      fi

      ssh_allow_lines="$(echo "$ufw_status" | grep -E '22/tcp[[:space:]]+ALLOW' || true)"
      if [[ -z "$ssh_allow_lines" ]]; then
        fail "No UFW allow rule found for SSH (22/tcp)"
      elif echo "$ssh_allow_lines" | grep -Eq 'Anywhere|0\.0\.0\.0/0|::/0'; then
        fail "SSH appears broadly exposed in UFW rules:\n$ssh_allow_lines"
      elif echo "$ssh_allow_lines" | grep -Fq "$LAN_CIDR"; then
        pass "UFW restricts SSH access to $LAN_CIDR"
      else
        warn "SSH allow rule exists but does not match expected LAN_CIDR=$LAN_CIDR:\n$ssh_allow_lines"
      fi

      if echo "$ufw_status" | grep -Eq '18789/tcp[[:space:]]+DENY'; then
        pass "UFW denies 18789/tcp"
      else
        fail "UFW deny rule for 18789/tcp not found"
      fi

      if echo "$ufw_status" | grep -Eq '18790/tcp[[:space:]]+DENY'; then
        pass "UFW denies 18790/tcp"
      else
        fail "UFW deny rule for 18790/tcp not found"
      fi

      if [[ -f adguard/.env ]]; then
        adguard_dns_rules="$(echo "$ufw_status" | grep -E '53/(tcp|udp)[[:space:]]+ALLOW' || true)"
        if [[ -z "$adguard_dns_rules" ]]; then
          warn "AdGuard stack is present but no UFW allow rules were found for DNS (53/tcp, 53/udp)"
        elif echo "$adguard_dns_rules" | grep -Eq 'Anywhere|0\.0\.0\.0/0|::/0'; then
          fail "AdGuard DNS appears broadly exposed in UFW rules:\n$adguard_dns_rules"
        elif echo "$adguard_dns_rules" | grep -Fq "$LAN_CIDR"; then
          pass "AdGuard DNS is restricted to $LAN_CIDR"
        else
          warn "AdGuard DNS rules exist but do not match expected LAN_CIDR=$LAN_CIDR:\n$adguard_dns_rules"
        fi

        adguard_ui_rules="$(echo "$ufw_status" | grep -E '300(0|1)/tcp[[:space:]]+ALLOW' || true)"
        if [[ -n "$adguard_ui_rules" ]]; then
          if echo "$adguard_ui_rules" | grep -Eq 'Anywhere|0\.0\.0\.0/0|::/0'; then
            fail "AdGuard admin UI appears broadly exposed in UFW rules:\n$adguard_ui_rules"
          elif echo "$adguard_ui_rules" | grep -Fq "$LAN_CIDR"; then
            pass "AdGuard admin UI is restricted to $LAN_CIDR"
          else
            warn "AdGuard admin UI rules exist but do not match expected LAN_CIDR=$LAN_CIDR:\n$adguard_ui_rules"
          fi
        else
          warn "AdGuard admin UI rules (3000/tcp or 3001/tcp) were not found; ensure setup UI is LAN-only if you use it"
        fi
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
  elif echo "$openclaw_ports" | grep -Eq '0\.0\.0\.0:1878[90]|\[::\]:1878[90]'; then
    fail "OpenClaw port is listening on public interfaces:\n$openclaw_ports"
  elif echo "$openclaw_ports" | grep -Eq '127\.0\.0\.1:1878[90]|\[::1\]:1878[90]'; then
    pass "OpenClaw is bound to loopback only"
  else
    warn "OpenClaw ports are listening on non-public interfaces:\n$openclaw_ports"
  fi

  docker_remote_api="$(ss -ltnH '( sport = :2375 or sport = :2376 )' 2>/dev/null || true)"
  if [[ -n "$docker_remote_api" ]]; then
    fail "Docker remote API appears exposed:\n$docker_remote_api"
  else
    pass "Docker remote API ports (2375/2376) are not listening"
  fi

  ollama_port="$(ss -ltnH '( sport = :11434 )' 2>/dev/null || true)"
  if [[ -z "$ollama_port" ]]; then
    warn "Ollama port (11434) is not listening"
  elif echo "$ollama_port" | grep -Eq '0\.0\.0\.0:11434|\[::\]:11434'; then
    fail "Ollama appears publicly bound; keep it localhost-only:\n$ollama_port"
  else
    pass "Ollama port (11434) is not publicly exposed"
  fi
else
  warn "Could not run socket checks because ss is unavailable"
fi

if command -v docker >/dev/null 2>&1; then
  docker_root_dir="$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || true)"
  if [[ -z "$docker_root_dir" ]]; then
    warn "Could not read Docker Root Dir (daemon may be down or requires sudo)"
  elif [[ "$docker_root_dir" == "/srv/docker" ]]; then
    pass "Docker Root Dir is /srv/docker"
  else
    warn "Docker Root Dir is $docker_root_dir (expected /srv/docker for this host layout)"
  fi
else
  warn "Docker CLI is not installed"
fi

if command -v systemctl >/dev/null 2>&1; then
  if id -u openclaw >/dev/null 2>&1; then
    if id -nG openclaw | tr ' ' '\n' | grep -Fxq 'docker'; then
      pass "openclaw user is a member of docker group"
    else
      fail "openclaw user is not in docker group"
    fi
  else
    warn "openclaw user is not present"
  fi

  if systemctl list-unit-files 2>/dev/null | grep -Eq '^openclaw-gateway\.service([[:space:]]|$)'; then
    if run_with_optional_sudo systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
      pass "openclaw-gateway service is active"
    else
      warn "openclaw-gateway service is installed but not active"
    fi

    openclaw_groups="$(run_with_optional_sudo systemctl show openclaw-gateway -p SupplementaryGroups --value 2>/dev/null || true)"
    if [[ -z "$openclaw_groups" ]]; then
      warn "Could not read openclaw-gateway supplementary groups"
    elif echo "$openclaw_groups" | grep -Eq '(^| )docker( |$)'; then
      pass "openclaw-gateway service has docker supplementary group"
    else
      fail "openclaw-gateway service is missing docker supplementary group"
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
