#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WARN_DAYS="${WARN_DAYS:-30}"
CRIT_DAYS="${CRIT_DAYS:-7}"

pass_count=0; warn_count=0; fail_count=0
pass() { echo "[PASS] $1"; pass_count=$((pass_count+1)); }
warn() { echo "[WARN] $1"; warn_count=$((warn_count+1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count+1)); }

echo "=== Caddy Certificate Monitor ==="
echo "Date: $(date)"
echo ""

if [[ ! -f proxy/.env ]]; then
  fail "proxy/.env not found"
  exit 1
fi

ROOT_DOMAIN=$(grep '^ROOT_DOMAIN=' proxy/.env | cut -d= -f2 | tr -d '"'"'" || echo "")
if [[ -z "$ROOT_DOMAIN" ]]; then
  fail "ROOT_DOMAIN not set in proxy/.env"
  exit 1
fi
echo "Root domain: $ROOT_DOMAIN"
echo ""

# Extract subdomains from Caddyfile (lines like: subdomain.{$ROOT_DOMAIN} {)
subdomains=$(grep -oP '^[a-zA-Z0-9._-]+(?=\.\{\$ROOT_DOMAIN\})' proxy/Caddyfile 2>/dev/null || true)

while IFS= read -r sub; do
  [[ -z "$sub" ]] && continue
  domain="${sub}.${ROOT_DOMAIN}"
  echo "Checking: $domain"

  expiry=$(echo | timeout 5 openssl s_client -servername "$domain" -connect "${domain}:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "")

  if [[ -z "$expiry" ]]; then
    warn "$domain — could not retrieve cert"
    continue
  fi

  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
  days_left=$(( (expiry_epoch - $(date +%s)) / 86400 ))

  if (( days_left <= CRIT_DAYS )); then
    fail "$domain — CRITICAL: expires in ${days_left}d"
  elif (( days_left <= WARN_DAYS )); then
    warn "$domain — expires in ${days_left}d"
  else
    pass "$domain — ${days_left}d remaining"
  fi
done <<< "$subdomains"

echo ""
echo "=== Summary: ${pass_count} pass, ${warn_count} warn, ${fail_count} fail ==="
(( fail_count > 0 )) && exit 2
(( warn_count > 0 )) && exit 1
exit 0
