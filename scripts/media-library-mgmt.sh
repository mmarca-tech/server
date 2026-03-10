#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

WARN_DISK_PCT="${WARN_DISK_PCT:-80}"
FAIL_DISK_PCT="${FAIL_DISK_PCT:-90}"
MEDIA_ROOT="${MEDIA_ROOT:-/srv/media}"

pass_count=0; warn_count=0; fail_count=0
pass() { echo "[PASS] $1"; pass_count=$((pass_count+1)); }
warn() { echo "[WARN] $1"; warn_count=$((warn_count+1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count+1)); }

echo "=== Media Library Health Check ==="
echo "Date: $(date)"
echo ""

# /srv disk usage
echo "--- Disk Usage ---"
df -h /srv 2>/dev/null || df -h /
echo ""

usage_pct=$(df /srv 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}' \
  || df / | awk 'NR==2{gsub(/%/,"",$5); print $5}')

if (( usage_pct >= FAIL_DISK_PCT )); then
  fail "/srv disk critical: ${usage_pct}%"
elif (( usage_pct >= WARN_DISK_PCT )); then
  warn "/srv disk high: ${usage_pct}%"
else
  pass "/srv disk OK: ${usage_pct}%"
fi

# Media subdirectories
echo ""
echo "--- Media Sizes ---"
if [[ -d "$MEDIA_ROOT" ]]; then
  du -sh "${MEDIA_ROOT}"/* 2>/dev/null | sort -h || echo "(empty)"
  pass "Media root accessible"
else
  fail "Media root not found: $MEDIA_ROOT"
fi

# Key media services
echo ""
echo "--- Service Status ---"
for svc in jellyfin navidrome audiobookshelf calibre-web; do
  if docker ps --filter "name=${svc}" --filter "status=running" -q | grep -q .; then
    pass "$svc running"
  else
    warn "$svc NOT running"
  fi
done

echo ""
echo "=== Summary: ${pass_count} pass, ${warn_count} warn, ${fail_count} fail ==="
(( fail_count > 0 )) && exit 2
(( warn_count > 0 )) && exit 1
exit 0
