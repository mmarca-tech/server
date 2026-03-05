#!/usr/bin/env bash
# torrent-search.sh — Non-interactive torrent search for OpenClaw/Telegram
# Usage:
#   ./torrent-search.sh search "query"                      → JSON array of results
#   ./torrent-search.sh download "magnet_url" [download_dir] → Add to Transmission
#   ./torrent-search.sh status                               → List active torrents
#   ./torrent-search.sh resolve "1337x_url"                  → Get magnet from page
#
# Dependencies: curl, python3

set -euo pipefail

# ── Transmission config ──────────────────────────────────────────────────────
TR_HOST="${TR_HOST:-127.0.0.1}"
TR_PORT="${TR_PORT:-9091}"
TR_USER="${TR_USER:-}"
TR_PASS="${TR_PASS:-}"

# ── Helpers ───────────────────────────────────────────────────────────────────
urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1" 2>/dev/null \
    || printf '%s' "$1" | sed 's/ /+/g'
}

json_escape() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null
}

# ── TPB Scraper ───────────────────────────────────────────────────────────────
TPB_MIRRORS=(
  "https://tpb.party"
  "https://thepiratebay.org"
  "https://piratebay.live"
  "https://thepiratebay10.info"
)

search_tpb() {
  local query="$1" encoded
  encoded=$(urlencode "$query")
  local html=""

  for m in "${TPB_MIRRORS[@]}"; do
    html=$(curl -sL --max-time 12 "$m/search/$encoded/1/99/0" 2>/dev/null) || continue
    [[ ${#html} -gt 1000 ]] && break
    html=""
  done
  [[ -z "$html" ]] && return

  # Extract magnets (contain name in dn= param) and seeds/leeches pairs
  local magnets seeds_list
  magnets=$(echo "$html" | grep -oP 'magnet:\?[^"]+')
  seeds_list=$(echo "$html" | grep -oP '(?<=<td align="right">)[0-9]+(?=</td>)')

  # Pair them up: every 2 seed values = seeds, leeches for one torrent
  local i=0
  local -a seed_arr=()
  while IFS= read -r s; do
    seed_arr+=("$s")
  done <<< "$seeds_list"

  local idx=0
  while IFS= read -r magnet; do
    local name seeds
    # Extract name from dn= parameter
    name=$(echo "$magnet" | grep -oP '(?<=dn=)[^&]+' | python3 -c "import urllib.parse,sys; print(urllib.parse.unquote_plus(sys.stdin.read().strip()))" 2>/dev/null || echo "Unknown")
    seeds="${seed_arr[$idx]:-0}"
    idx=$((idx + 2))  # skip leeches

    [[ -n "$name" && "$name" != "Unknown" ]] && printf 'TPB\t%s\t-\t%s\t%s\n' "$name" "$seeds" "$magnet"
  done <<< "$magnets" 2>/dev/null || true
}

# ── 1337x Scraper ─────────────────────────────────────────────────────────────
LEET_MIRRORS=(
  "https://www.1337x.to"
  "https://1337x.tw"
  "https://1337x.gd"
)

search_1337x() {
  local query="$1" encoded
  encoded=$(urlencode "$query")
  local html="" mirror=""

  for m in "${LEET_MIRRORS[@]}"; do
    html=$(curl -sL --max-time 12 "$m/search/$encoded/1/" 2>/dev/null) || continue
    [[ ${#html} -gt 1000 ]] && { mirror="$m"; break; }
    html=""
  done
  [[ -z "$mirror" ]] && return

  # Parse using Python for reliability
  python3 -c "
import re, sys, html as h

data = sys.stdin.read()

# Find table rows in the search results
rows = re.findall(r'<tr>(.*?)</tr>', data, re.DOTALL)

for row in rows:
    # Get torrent link and name
    link_match = re.search(r'href=\"(/torrent/[^\"]+)\"[^>]*>([^<]+)', row)
    if not link_match:
        continue
    link = link_match.group(1)
    name = h.unescape(link_match.group(2)).strip()

    # Get seeds
    seed_match = re.search(r'class=\"seeds\">(\d+)', row)
    seeds = seed_match.group(1) if seed_match else '0'

    # Get size
    size_match = re.search(r'class=\"size\">([\d.]+ [KMGT]+i?B)', row)
    size = size_match.group(1) if size_match else '-'

    url = '${mirror}' + link
    print(f'1337X\t{name}\t{size}\t{seeds}\t{url}')
" <<< "$html" 2>/dev/null | head -20 || true
}

# ── Nyaa Scraper ──────────────────────────────────────────────────────────────
search_nyaa() {
  local query="$1" encoded
  encoded=$(urlencode "$query")
  local html
  html=$(curl -sL --max-time 12 "https://nyaa.si/?f=0&c=0_0&q=$encoded" 2>/dev/null) || return

  python3 -c "
import re, sys, html as h

data = sys.stdin.read()
rows = re.findall(r'<tr class=\"(?:default|success|danger)\">.*?</tr>', data, re.DOTALL)

for row in rows:
    title_match = re.search(r'title=\"([^\"]+)\"', row)
    if not title_match:
        continue
    name = h.unescape(title_match.group(1)).strip()

    magnet_match = re.search(r'(magnet:\?[^\"]+)', row)
    magnet = magnet_match.group(1) if magnet_match else ''
    if not magnet:
        continue

    size_match = re.search(r'(\d+\.?\d*\s*[KMGTi]+B)', row)
    size = size_match.group(1) if size_match else '-'

    seed_match = re.search(r'class=\"text-success\">(\d+)', row)
    seeds = seed_match.group(1) if seed_match else '0'

    print(f'NYAA\t{name}\t{size}\t{seeds}\t{magnet}')
" <<< "$html" 2>/dev/null | head -20 || true
}

# ── Search command ────────────────────────────────────────────────────────────
do_search() {
  local query="$1"
  local tmpfile
  tmpfile=$(mktemp)

  # Run all scrapers in parallel
  (search_tpb   "$query" 2>/dev/null || true) >> "$tmpfile" &
  local pid1=$!
  (search_1337x "$query" 2>/dev/null || true) >> "$tmpfile" &
  local pid2=$!
  (search_nyaa  "$query" 2>/dev/null || true) >> "$tmpfile" &
  local pid3=$!

  wait $pid1 $pid2 $pid3 2>/dev/null || true

  # Filter: seeds > 0, has a link, sort by seeds desc
  local filtered
  filtered=$(mktemp)
  awk -F'\t' 'NF>=5 && $4+0 > 0 && $5 != ""' "$tmpfile" | sort -t$'\t' -k4 -rn | head -15 > "$filtered"
  rm -f "$tmpfile"

  local count
  count=$(wc -l < "$filtered")

  if [[ "$count" -eq 0 ]]; then
    echo "[]"
    rm -f "$filtered"
    return
  fi

  # Output as JSON
  python3 -c "
import json, sys

results = []
for i, line in enumerate(sys.stdin, 1):
    parts = line.strip().split('\t', 4)
    if len(parts) < 5:
        continue
    results.append({
        'id': i,
        'source': parts[0],
        'name': parts[1],
        'size': parts[2],
        'seeds': int(parts[3]) if parts[3].isdigit() else 0,
        'link': parts[4]
    })

print(json.dumps(results, indent=2))
" < "$filtered"

  rm -f "$filtered"
}

# ── Download command ──────────────────────────────────────────────────────────
do_download() {
  local link="$1"
  local download_dir="${2:-}"

  if ! command -v transmission-remote &>/dev/null; then
    echo '{"ok":false,"error":"transmission-remote not installed"}'
    return 1
  fi

  local tr_cmd=(transmission-remote "${TR_HOST}:${TR_PORT}")
  [[ -n "$TR_USER" ]] && tr_cmd+=(--auth "${TR_USER}:${TR_PASS}")
  [[ -n "$download_dir" ]] && tr_cmd+=(--download-dir "$download_dir")
  tr_cmd+=(--add "$link")

  local output
  if output=$("${tr_cmd[@]}" 2>&1); then
    echo '{"ok":true,"message":"Torrent added successfully"}'
  else
    local jerr
    jerr=$(echo "$output" | json_escape)
    printf '{"ok":false,"error":%s}\n' "$jerr"
    return 1
  fi
}

# ── Status command ────────────────────────────────────────────────────────────
do_status() {
  if ! command -v transmission-remote &>/dev/null; then
    echo '{"ok":false,"error":"transmission-remote not installed"}'
    return 1
  fi

  local tr_cmd=(transmission-remote "${TR_HOST}:${TR_PORT}")
  [[ -n "$TR_USER" ]] && tr_cmd+=(--auth "${TR_USER}:${TR_PASS}")
  tr_cmd+=(--list)

  "${tr_cmd[@]}" 2>&1 || true
}

# ── Resolve magnet from 1337x page ───────────────────────────────────────────
do_resolve_magnet() {
  local url="$1"
  local html
  html=$(curl -sL --max-time 12 "$url" 2>/dev/null) || { echo ""; return; }
  echo "$html" | grep -oP 'magnet:\?[^"]+' | head -1
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
  search)
    [[ -z "${2:-}" ]] && { echo '{"error":"No query provided"}'; exit 1; }
    do_search "$2"
    ;;
  download)
    [[ -z "${2:-}" ]] && { echo '{"error":"No link provided"}'; exit 1; }
    do_download "$2" "${3:-}"
    ;;
  status)
    do_status
    ;;
  resolve)
    [[ -z "${2:-}" ]] && { echo '{"error":"No URL provided"}'; exit 1; }
    do_resolve_magnet "$2"
    ;;
  *)
    echo "Usage: $0 {search|download|status|resolve} [args...]"
    exit 1
    ;;
esac
