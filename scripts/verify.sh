#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
runtime=false
[[ "${1:-}" == "--runtime" ]] && runtime=true

failures=0
pass() { echo "[PASS] $*"; }
fail() {
  echo "[FAIL] $*"
  failures=$((failures + 1))
}

removed_pattern='open''claw|claw''dbot'
if rg -n -i "$removed_pattern" "$REPO_ROOT" --glob '!.git/**' --glob '!nohup.out' >/dev/null 2>&1; then
  fail "Removed agent names remain in tracked content"
else
  pass "No removed agent references"
fi

if rg -n '(^|:)(latest|release|stable)(@|$)' "$REPO_ROOT" --glob '*.yml' --glob '*.yaml' --glob '*.env' --glob 'Dockerfile*' >/dev/null 2>&1; then
  fail "Mutable image references remain"
else
  pass "Container images are immutable"
fi

if git -C "$REPO_ROOT" ls-files | while IFS= read -r file; do [[ -e "$REPO_ROOT/$file" ]] && echo "$file"; done | grep -Eq '(^|/)(\.env|db\.sqlite3|oidc\.key|users_database\.yml|notification\.txt)$'; then
  fail "Runtime secrets or data are tracked"
else
  pass "No runtime secrets or data are tracked"
fi

while IFS= read -r script; do
  bash -n "$script" || fail "Bash syntax: $script"
done < <(find "$REPO_ROOT/scripts" -type f -name '*.sh' -print)

if $runtime; then
  [[ ${EUID} -eq 0 ]] || {
    echo "Runtime verification requires root" >&2
    exit 1
  }
  # shellcheck source=scripts/lib/common.sh
  source "$SCRIPT_DIR/lib/common.sh"
  load_environment
  if systemctl is-active --quiet docker; then pass "Docker active"; else fail "Docker inactive"; fi
  if systemctl is-active --quiet wg-quick@wg0; then pass "WireGuard active"; else fail "WireGuard inactive"; fi
  if ufw status | grep -q '^Status: active'; then pass "UFW active"; else fail "UFW inactive"; fi
  ufw_rules="$(ufw status)"
  for port in "${SSH_PORT:-22}/tcp" 80/tcp 443/tcp 443/udp "${WG_PORT}/udp" "${GITEA_SSH_PORT:-2222}/tcp"; do
    if echo "$ufw_rules" | grep -Fq "$port"; then pass "UFW permits $port"; else fail "UFW is missing $port"; fi
  done
  if iptables -C DOCKER-USER -i "$(ip route show default | awk 'NR==1 {print $5}')" -j DROP 2>/dev/null; then
    pass "Docker external-interface drop policy is active"
  else
    fail "Docker external-interface drop policy is missing"
  fi
  unhealthy="$(docker ps --filter health=unhealthy --format '{{.Names}}')"
  if [[ -z "$unhealthy" ]]; then pass "No unhealthy containers"; else fail "Unhealthy containers: $unhealthy"; fi
  public_listeners="$(ss -lntupH | awk '$5 ~ /0\.0\.0\.0:|\[::\]:|\*:/ {print $5}' | sort -u)"
  if echo "$public_listeners" | grep -Ev ":(${SSH_PORT:-22}|80|443|${WG_PORT}|${GITEA_SSH_PORT:-2222})$" | grep -q .; then
    fail "Unexpected public listeners: $public_listeners"
  else
    pass "Public listeners are restricted"
  fi
  while IFS= read -r host; do
    if curl -fsS --connect-timeout 5 --max-time 20 --retry 6 --retry-delay 5 --retry-all-errors "https://$host/" >/dev/null; then
      pass "HTTPS endpoint responds: $host"
    else
      fail "HTTPS endpoint failed: $host"
    fi
  done < <(public_hosts)
fi

((failures == 0)) || exit 1
echo "Verification complete."
