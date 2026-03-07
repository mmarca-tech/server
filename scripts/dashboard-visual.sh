#!/bin/bash

# Visual Console Dashboard - Two-column layout

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
GRAY=$'\e[37m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

clear

# Header
echo "${CYAN}${BOLD}════════════════════════════════════════════════════════════════════════════════════════${RESET}"
echo "                          🖥️  HOME SERVER STATUS DASHBOARD"
echo "                                  $(date '+%Y-%m-%d %H:%M:%S')"
echo "${CYAN}${BOLD}════════════════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""

# Temp files
LEFT=$(mktemp)
RIGHT=$(mktemp)
trap "rm -f $LEFT $RIGHT" EXIT

# ── LEFT COLUMN: Docker Containers ──────────────────────────────────────────
{
    RUNNING=$(docker ps --format "{{.State}}" 2>/dev/null | grep -c "running" || echo "0")
    TOTAL=$(docker ps -a --format "{{.State}}" 2>/dev/null | wc -l)

    echo "${BLUE}${BOLD}DOCKER CONTAINERS${RESET}"
    echo "─────────────────────────────────────────"
    echo "Running: ${GREEN}${RUNNING}${RESET} / ${TOTAL}"
    echo ""

    print_service() {
        local label="$1" search="$2"
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$search"; then
            container=$(docker ps -aqf "name=$search" 2>/dev/null | head -1)
            status=$(docker ps -a --format "{{.State}}" -f "id=$container" 2>/dev/null)
            uptime=$(docker ps -a --format "{{.RunningFor}}" -f "id=$container" 2>/dev/null | sed 's/ ago//' | cut -d' ' -f1-2)
            if [ "$status" = "running" ]; then
                printf "  ${GREEN}✓${RESET} %-26s ${GREEN}%s${RESET}\n" "$label" "$uptime"
            else
                printf "  ${RED}✗${RESET} %-26s ${RED}(stopped)${RESET}\n" "$label"
            fi
        else
            printf "  ${GRAY}–${RESET} %-26s ${GRAY}(not found)${RESET}\n" "$label"
        fi
    }

    echo "${GRAY}  Infrastructure${RESET}"
    print_service "caddy"                   "caddy"
    print_service "adguard"                 "adguard"
    print_service "homeassistant"           "homeassistant"
    print_service "mollysocket"             "mollysocket"

    echo "${GRAY}  Media${RESET}"
    print_service "jellyfin"                "jellyfin"
    print_service "jellyseerr"              "jellyseerr"
    print_service "navidrome"               "navidrome"
    print_service "audiobookshelf"          "audiobookshelf"
    print_service "calibre-web"             "calibre-web"

    echo "${GRAY}  Arr Stack${RESET}"
    print_service "sonarr"                  "sonarr"
    print_service "radarr"                  "radarr"
    print_service "prowlarr"                "prowlarr"
    print_service "bazarr"                  "bazarr"
    print_service "tdarr"                   "tdarr"
    print_service "recyclarr"               "recyclarr"
    print_service "flaresolverr"            "flaresolverr"

    echo "${GRAY}  Downloads${RESET}"
    print_service "gluetun"                 "gluetun"
    print_service "transmission"            "transmission"

    echo "${GRAY}  Cloud / Photos${RESET}"
    print_service "nextcloud"               "nextcloud$"
    print_service "nextcloud-db"            "nextcloud-db"
    print_service "nextcloud-redis"         "nextcloud-redis"
    print_service "immich-server"           "immich-server"
    print_service "immich-machine-learning" "immich-machine"
    print_service "immich-db"               "immich-db"
    print_service "immich-redis"            "immich-redis"
} > "$LEFT"

# ── RIGHT COLUMN: VPN / Downloads / Queue / Disk / Network / System ─────────
{
    # VPN
    echo "${BLUE}${BOLD}VPN STATUS (Gluetun)${RESET}"
    echo "─────────────────────────────────────────"
    VPN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null)
    VPN_COUNTRY=$(docker exec gluetun wget -qO- https://ipinfo.io/country 2>/dev/null)
    GLUETUN_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' gluetun 2>/dev/null)
    if [ "$GLUETUN_HEALTH" = "healthy" ] && [ -n "$VPN_IP" ]; then
        printf "  ${GREEN}✓${RESET} Connected: ${GREEN}%s${RESET} (%s)\n" "$VPN_IP" "${VPN_COUNTRY:-unknown}"
    elif [ "$GLUETUN_HEALTH" = "healthy" ]; then
        printf "  ${GREEN}✓${RESET} Healthy ${YELLOW}(IP lookup timed out)${RESET}\n"
    else
        printf "  ${RED}✗${RESET} ${RED}Disconnected / Unhealthy${RESET}\n"
    fi
    VPN_PORT=$(docker exec gluetun cat /tmp/gluetun/forwarded_port 2>/dev/null)
    [ -n "$VPN_PORT" ] && printf "  Port forward: ${GREEN}%s${RESET}\n" "$VPN_PORT"
    echo ""

    # Downloads
    echo "${BLUE}${BOLD}DOWNLOADS (Transmission)${RESET}"
    echo "─────────────────────────────────────────"
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "gluetun"; then
        TR_LIST=$(transmission-remote 127.0.0.1:9091 --list 2>/dev/null)
        if [ $? -eq 0 ]; then
            DOWNLOADING=$(echo "$TR_LIST" | grep -c "Downloading" || echo "0")
            SEEDING=$(echo "$TR_LIST" | grep -c "Seeding" || echo "0")
            IDLE=$(echo "$TR_LIST" | grep -c "Idle" || echo "0")
            printf "  ${CYAN}%s${RESET} downloading  ${GREEN}%s${RESET} seeding  ${GRAY}%s${RESET} idle\n" "$DOWNLOADING" "$SEEDING" "$IDLE"
            echo "$TR_LIST" | grep "Downloading" | while read -r line; do
                NAME=$(echo "$line" | awk '{for(i=10;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
                PCT=$(echo "$line" | awk '{print $2}')
                ETA=$(echo "$line" | awk '{print $5}')
                printf "    ↓ ${YELLOW}%-32.32s${RESET} %s  ETA:%s\n" "$NAME" "$PCT" "$ETA"
            done
        else
            printf "  ${YELLOW}⚠${RESET} Cannot connect to Transmission\n"
        fi
    else
        printf "  ${RED}✗${RESET} Gluetun not running\n"
    fi
    echo ""

    # Media Queue
    echo "${BLUE}${BOLD}MEDIA QUEUE${RESET}"
    echo "─────────────────────────────────────────"
    SONARR_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' /srv/sonarr/config/config.xml 2>/dev/null)
    if [ -n "$SONARR_KEY" ]; then
        SONARR_Q=$(curl -sf "http://localhost:8989/api/v3/queue?apikey=${SONARR_KEY}" 2>/dev/null)
        SONARR_COUNT=$(echo "$SONARR_Q" | grep -o '"totalRecords":[0-9]*' | grep -o '[0-9]*')
        printf "  Sonarr: ${CYAN}%s${RESET} items in queue\n" "${SONARR_COUNT:-0}"
    else
        printf "  Sonarr: ${GRAY}(not configured)${RESET}\n"
    fi
    RADARR_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' /srv/radarr/config/config.xml 2>/dev/null)
    if [ -n "$RADARR_KEY" ]; then
        RADARR_Q=$(curl -sf "http://localhost:7878/api/v3/queue?apikey=${RADARR_KEY}" 2>/dev/null)
        RADARR_COUNT=$(echo "$RADARR_Q" | grep -o '"totalRecords":[0-9]*' | grep -o '[0-9]*')
        printf "  Radarr: ${CYAN}%s${RESET} items in queue\n" "${RADARR_COUNT:-0}"
    else
        printf "  Radarr: ${GRAY}(not configured)${RESET}\n"
    fi
    echo ""

    # Disk
    echo "${BLUE}${BOLD}DISK USAGE${RESET}"
    echo "─────────────────────────────────────────"
    print_disk_bar() {
        local label="$1" usage="$2" info="$3"
        printf "  %-16s" "$label"
        if [ "$usage" -lt 80 ]; then printf "${GREEN}"
        elif [ "$usage" -lt 90 ]; then printf "${YELLOW}"
        else printf "${RED}"; fi
        for ((i=0; i<$((usage/5)); i++)); do printf "█"; done
        printf "${GRAY}"
        for ((i=0; i<$((20-usage/5)); i++)); do printf "░"; done
        printf "${RESET} %3d%%  ${GRAY}%s${RESET}\n" "$usage" "$info"
    }
    ROOT_USAGE=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
    ROOT_INFO=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2}')
    print_disk_bar "nvme0n1p2 (/)" "$ROOT_USAGE" "$ROOT_INFO"
    EFI_USAGE=$(df /boot/efi 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
    EFI_INFO=$(df -h /boot/efi 2>/dev/null | awk 'NR==2 {print $3 " / " $2}')
    [ -n "$EFI_USAGE" ] && print_disk_bar "nvme0n1p1 (EFI)" "$EFI_USAGE" "$EFI_INFO"
    echo ""
    MOVIES_SIZE=$(du -sh /srv/media/movies 2>/dev/null | awk '{print $1}')
    SERIES_SIZE=$(du -sh /srv/media/series 2>/dev/null | awk '{print $1}')
    MUSIC_SIZE=$(du -sh /srv/media/music 2>/dev/null | awk '{print $1}')
    BOOKS_SIZE=$(du -sh /srv/media/books 2>/dev/null | awk '{print $1}')
    DL_SIZE=$(du -sh /srv/media/downloads 2>/dev/null | awk '{print $1}')
    [ -n "$MOVIES_SIZE" ] && {
        printf "  Movies: ${CYAN}%-7s${RESET}  Series: ${CYAN}%-7s${RESET}\n" "$MOVIES_SIZE" "${SERIES_SIZE:--}"
        printf "  Music:  ${CYAN}%-7s${RESET}  Books:  ${CYAN}%-7s${RESET}\n" "${MUSIC_SIZE:--}" "${BOOKS_SIZE:--}"
        printf "  Downloads: ${CYAN}%s${RESET}\n" "${DL_SIZE:--}"
    }
    echo ""

    # Network
    echo "${BLUE}${BOLD}NETWORK${RESET}"
    echo "─────────────────────────────────────────"
    IFACE=$(ip route | awk '/default/ {print $5; exit}')
    if [ -n "$IFACE" ]; then
        RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null)
        TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null)
        sleep 1
        RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null)
        TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null)
        if [ -n "$RX1" ] && [ -n "$RX2" ]; then
            RX_RATE=$(( (RX2 - RX1) / 1024 ))
            TX_RATE=$(( (TX2 - TX1) / 1024 ))
            [ "$RX_RATE" -gt 1024 ] && RX_FMT="$(( RX_RATE/1024 )) MB/s" || RX_FMT="${RX_RATE} KB/s"
            [ "$TX_RATE" -gt 1024 ] && TX_FMT="$(( TX_RATE/1024 )) MB/s" || TX_FMT="${TX_RATE} KB/s"
            printf "  %s: ↓ ${GREEN}%s${RESET}  ↑ ${CYAN}%s${RESET}\n" "$IFACE" "$RX_FMT" "$TX_FMT"
            printf "  Boot totals: ↓ %d GB  ↑ %d GB\n" "$(( RX2/1073741824 ))" "$(( TX2/1073741824 ))"
        fi
    else
        printf "  ${YELLOW}Could not detect network interface${RESET}\n"
    fi
    echo ""

    # System
    echo "${BLUE}${BOLD}SYSTEM INFO${RESET}"
    echo "─────────────────────────────────────────"
    echo "  Uptime: ${CYAN}$(uptime -p)${RESET}"
    echo "  Load:   ${YELLOW}$(uptime | awk -F'load average:' '{print $NF}')${RESET}"
    MEM_PERCENT=$(free 2>/dev/null | awk 'NR==2 {printf "%.0f", $3/$2 * 100.0}')
    printf "  Memory: "
    if [ "$MEM_PERCENT" -lt 80 ]; then printf "${GREEN}"; else printf "${RED}"; fi
    for ((i=0; i<$((MEM_PERCENT/5)); i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0; i<$((20-MEM_PERCENT/5)); i++)); do printf "░"; done
    printf "${RESET} %3d%%\n" "$MEM_PERCENT"
} > "$RIGHT"

# ── RENDER SIDE BY SIDE ──────────────────────────────────────────────────────
# COL_WIDTH: visible character width reserved for the left column
COL_WIDTH=50

mapfile -t L < "$LEFT"
mapfile -t R < "$RIGHT"
MAX=$(( ${#L[@]} > ${#R[@]} ? ${#L[@]} : ${#R[@]} ))

for ((i=0; i<MAX; i++)); do
    ll="${L[$i]:-}"
    rr="${R[$i]:-}"
    # Strip ANSI codes to measure visible width
    vlen=$(printf '%s' "$ll" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' | wc -m)
    pad=$(( COL_WIDTH - vlen ))
    [ "$pad" -lt 0 ] && pad=0
    printf '%s%*s  │  %s\n' "$ll" "$pad" "" "$rr"
done

echo ""
echo "${GRAY}Live updates: watch -n 5 /srv/server/scripts/dashboard-visual.sh${RESET}"
echo ""
