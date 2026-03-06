#!/bin/bash

# Visual Console Dashboard - Robust Version

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
echo "${CYAN}${BOLD}════════════════════════════════════════════════════════════════${RESET}"
echo "            🖥️  HOME SERVER STATUS DASHBOARD"
echo "                $(date '+%Y-%m-%d %H:%M:%S')"
echo "${CYAN}${BOLD}════════════════════════════════════════════════════════════════${RESET}"
echo ""

# Docker Status
RUNNING=$(docker ps --format "{{.State}}" 2>/dev/null | grep -c "running" || echo "0")
TOTAL=$(docker ps -a --format "{{.State}}" 2>/dev/null | wc -l)

echo "${BLUE}${BOLD}DOCKER CONTAINERS${RESET}"
echo "─────────────────────────────────────────"
echo "Running: ${GREEN}${RUNNING}${RESET} / ${TOTAL}"
echo ""
echo "Services:"

# List services
for service in jellyfin immich-server navidrome nextcloud caddy adguard homeassistant calibre-web jellyseerr audiobookshelf gluetun transmission sonarr radarr prowlarr flaresolverr bazarr tdarr recyclarr; do
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$service"; then
        container=$(docker ps -aqf "name=$service" 2>/dev/null | head -1)
        status=$(docker ps -a --format "{{.State}}" -f "id=$container" 2>/dev/null)
        uptime=$(docker ps -a --format "{{.RunningFor}}" -f "id=$container" 2>/dev/null | sed 's/ ago//' | cut -d' ' -f1-2)
        
        if [ "$status" = "running" ]; then
            printf "  ${GREEN}✓${RESET} %-20s ${GREEN}%s${RESET}\n" "$service" "$uptime"
        else
            printf "  ${RED}✗${RESET} %-20s ${RED}(stopped)${RESET}\n" "$service"
        fi
    fi
done

# ── VPN STATUS ──────────────────────────────────────────────
echo ""
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

# Port forward status
VPN_PORT=$(docker exec gluetun cat /tmp/gluetun/forwarded_port 2>/dev/null)
if [ -n "$VPN_PORT" ]; then
    printf "  Port forward: ${GREEN}%s${RESET}\n" "$VPN_PORT"
fi

# ── DOWNLOADS ───────────────────────────────────────────────
echo ""
echo "${BLUE}${BOLD}DOWNLOADS (Transmission)${RESET}"
echo "─────────────────────────────────────────"

if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "gluetun"; then
    TR_LIST=$(transmission-remote 127.0.0.1:9091 --list 2>/dev/null)
    if [ $? -eq 0 ]; then
        TOTAL_TORRENTS=$(echo "$TR_LIST" | tail -1 | awk '{print $1}' 2>/dev/null)
        DOWNLOADING=$(echo "$TR_LIST" | grep -c "Downloading" 2>/dev/null || echo "0")
        SEEDING=$(echo "$TR_LIST" | grep -c "Seeding" 2>/dev/null || echo "0")
        IDLE=$(echo "$TR_LIST" | grep -c "Idle" 2>/dev/null || echo "0")

        printf "  Active: ${CYAN}%s${RESET} downloading, ${GREEN}%s${RESET} seeding, ${GRAY}%s${RESET} idle\n" "$DOWNLOADING" "$SEEDING" "$IDLE"

        # Show active downloads with progress
        echo "$TR_LIST" | grep "Downloading" | while read -r line; do
            NAME=$(echo "$line" | awk '{for(i=10;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
            PCT=$(echo "$line" | awk '{print $2}')
            ETA=$(echo "$line" | awk '{print $5}')
            printf "    ↓ ${YELLOW}%-40.40s${RESET} %s  ETA: %s\n" "$NAME" "$PCT" "$ETA"
        done
    else
        printf "  ${YELLOW}⚠${RESET} Cannot connect to Transmission\n"
    fi
else
    printf "  ${RED}✗${RESET} Gluetun not running\n"
fi

# ── MEDIA QUEUE (Sonarr/Radarr) ────────────────────────────
echo ""
echo "${BLUE}${BOLD}MEDIA QUEUE${RESET}"
echo "─────────────────────────────────────────"

# Sonarr queue
SONARR_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' /srv/sonarr/config/config.xml 2>/dev/null)
if [ -n "$SONARR_KEY" ]; then
    SONARR_Q=$(curl -sf "http://localhost:8989/api/v3/queue?apikey=${SONARR_KEY}" 2>/dev/null)
    SONARR_COUNT=$(echo "$SONARR_Q" | grep -o '"totalRecords":[0-9]*' | grep -o '[0-9]*')
    printf "  Sonarr:  ${CYAN}%s${RESET} items in queue\n" "${SONARR_COUNT:-0}"
else
    printf "  Sonarr:  ${GRAY}(not configured)${RESET}\n"
fi

# Radarr queue
RADARR_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' /srv/radarr/config/config.xml 2>/dev/null)
if [ -n "$RADARR_KEY" ]; then
    RADARR_Q=$(curl -sf "http://localhost:7878/api/v3/queue?apikey=${RADARR_KEY}" 2>/dev/null)
    RADARR_COUNT=$(echo "$RADARR_Q" | grep -o '"totalRecords":[0-9]*' | grep -o '[0-9]*')
    printf "  Radarr:  ${CYAN}%s${RESET} items in queue\n" "${RADARR_COUNT:-0}"
else
    printf "  Radarr:  ${GRAY}(not configured)${RESET}\n"
fi

# ── DISK USAGE ──────────────────────────────────────────────
echo ""
echo "${BLUE}${BOLD}DISK USAGE${RESET}"
echo "─────────────────────────────────────────"

ROOT_USAGE=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
SRV_USAGE=$(df /srv 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')

# Root disk bar
printf "  / (Root):     "
if [ "$ROOT_USAGE" -lt 80 ]; then
    printf "${GREEN}"
else
    printf "${RED}"
fi
for ((i=0; i<$((ROOT_USAGE/5)); i++)); do printf "█"; done
printf "${GRAY}"
for ((i=0; i<$((20-ROOT_USAGE/5)); i++)); do printf "░"; done
printf "${RESET} %3d%% ${RESET}\n" "$ROOT_USAGE"

# /srv disk bar
printf "  /srv (Media):  "
if [ "$SRV_USAGE" -lt 80 ]; then
    printf "${GREEN}"
else
    printf "${RED}"
fi
for ((i=0; i<$((SRV_USAGE/5)); i++)); do printf "█"; done
printf "${GRAY}"
for ((i=0; i<$((20-SRV_USAGE/5)); i++)); do printf "░"; done
printf "${RESET} %3d%% ${RESET}\n" "$SRV_USAGE"

# Media breakdown
MOVIES_SIZE=$(du -sh /srv/media/movies 2>/dev/null | awk '{print $1}')
SERIES_SIZE=$(du -sh /srv/media/series 2>/dev/null | awk '{print $1}')
MUSIC_SIZE=$(du -sh /srv/media/music 2>/dev/null | awk '{print $1}')
DL_SIZE=$(du -sh /srv/media/downloads 2>/dev/null | awk '{print $1}')
[ -n "$MOVIES_SIZE" ] && printf "  Movies: %-8s Series: %-8s Music: %-8s Downloads: %s\n" "$MOVIES_SIZE" "${SERIES_SIZE:-0}" "${MUSIC_SIZE:-0}" "${DL_SIZE:-0}"

# ── NETWORK THROUGHPUT ──────────────────────────────────────
echo ""
echo "${BLUE}${BOLD}NETWORK THROUGHPUT${RESET}"
echo "─────────────────────────────────────────"

# Get default interface
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

        # Format with units
        if [ "$RX_RATE" -gt 1024 ]; then
            RX_FMT="$(( RX_RATE / 1024 )) MB/s"
        else
            RX_FMT="${RX_RATE} KB/s"
        fi
        if [ "$TX_RATE" -gt 1024 ]; then
            TX_FMT="$(( TX_RATE / 1024 )) MB/s"
        else
            TX_FMT="${TX_RATE} KB/s"
        fi

        printf "  %s:  ↓ ${GREEN}%s${RESET}  ↑ ${CYAN}%s${RESET}\n" "$IFACE" "$RX_FMT" "$TX_FMT"

        # Total transferred
        RX_TOTAL=$(( RX2 / 1073741824 ))
        TX_TOTAL=$(( TX2 / 1073741824 ))
        printf "  Total since boot:  ↓ %d GB  ↑ %d GB\n" "$RX_TOTAL" "$TX_TOTAL"
    fi
else
    printf "  ${YELLOW}Could not detect network interface${RESET}\n"
fi

# ── SYSTEM INFO ─────────────────────────────────────────────
echo ""
echo "${BLUE}${BOLD}SYSTEM INFO${RESET}"
echo "─────────────────────────────────────────"
echo "  Uptime:  ${CYAN}$(uptime -p)${RESET}"
echo "  Load:    ${YELLOW}$(uptime | awk -F'load average:' '{print $NF}')${RESET}"

MEM_PERCENT=$(free 2>/dev/null | awk 'NR==2 {printf "%.0f", $3/$2 * 100.0}')
printf "  Memory:  "
if [ "$MEM_PERCENT" -lt 80 ]; then
    printf "${GREEN}"
else
    printf "${RED}"
fi
for ((i=0; i<$((MEM_PERCENT/5)); i++)); do printf "█"; done
printf "${GRAY}"
for ((i=0; i<$((20-MEM_PERCENT/5)); i++)); do printf "░"; done
printf "${RESET} %3d%% ${RESET}\n" "$MEM_PERCENT"

echo ""
echo "${GRAY}Live updates: watch -n 5 /srv/server/scripts/dashboard-visual.sh${RESET}"
echo ""
