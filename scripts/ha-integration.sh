#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

HA_URL="${HA_URL:-http://homeassistant:8123}"
HA_TOKEN_FILE="${HA_TOKEN_FILE:-$HOME/.openclaw/.ha_token}"

pass_count=0; warn_count=0; fail_count=0
pass() { echo "[PASS] $1"; pass_count=$((pass_count+1)); }
warn() { echo "[WARN] $1"; warn_count=$((warn_count+1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count+1)); }

echo "=== Home Assistant Status Check ==="
echo "Date: $(date)"
echo ""

# Container running?
if docker ps --filter "name=homeassistant" --filter "status=running" -q | grep -q .; then
  pass "Container is running"
else
  fail "Container is NOT running"
  echo "=== Summary: ${pass_count} pass, ${warn_count} warn, ${fail_count} fail ==="; exit 2
fi

# API reachable?
ha_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$HA_URL/api/" 2>/dev/null || echo "000")
if [[ "$ha_status" == "401" || "$ha_status" == "200" ]]; then
  pass "API reachable (HTTP $ha_status)"
else
  fail "API unreachable (HTTP $ha_status)"
fi

# Authenticated check
if [[ -f "$HA_TOKEN_FILE" ]]; then
  HA_TOKEN=$(cat "$HA_TOKEN_FILE")

  api_ok=$(curl -s --max-time 10 \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    "$HA_URL/api/" 2>/dev/null | grep -c '"message"' || echo 0)

  if (( api_ok > 0 )); then
    pass "API authenticated"
  else
    warn "Token auth failed or expired"
  fi

  # Unavailable entities
  unavail=$(curl -s --max-time 15 \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    "$HA_URL/api/states" 2>/dev/null \
    | python3 -c "
import sys, json
try:
    states = json.load(sys.stdin)
    u = [s['entity_id'] for s in states if s.get('state') == 'unavailable']
    print(len(u))
    for e in u[:10]: print(' -', e)
except: print(0)
" 2>/dev/null || echo 0)

  count=$(echo "$unavail" | head -1)
  if (( count == 0 )); then
    pass "No unavailable entities"
  elif (( count <= 5 )); then
    warn "$count unavailable entities"
    echo "$unavail" | tail -n +2
  else
    fail "$count unavailable entities (showing first 10)"
    echo "$unavail" | tail -n +2
  fi
fi

echo ""
echo "=== Summary: ${pass_count} pass, ${warn_count} warn, ${fail_count} fail ==="
(( fail_count > 0 )) && exit 2
(( warn_count > 0 )) && exit 1
exit 0
