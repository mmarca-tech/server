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
for service in jellyfin immich-server navidrome nextcloud caddy adguard homeassistant calibre-web jellyseerr audiobookshelf gluetun transmission sonarr radarr prowlarr flaresolverr; do
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

echo ""
echo "${BLUE}${BOLD}DISK USAGE${RESET}"
echo "─────────────────────────────────────────"

ROOT_USAGE=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
SRV_USAGE=$(df /srv 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')

# Root disk bar
printf "  / (Root):    "
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
printf "  /srv (Media): "
if [ "$SRV_USAGE" -lt 80 ]; then
    printf "${GREEN}"
else
    printf "${RED}"
fi
for ((i=0; i<$((SRV_USAGE/5)); i++)); do printf "█"; done
printf "${GRAY}"
for ((i=0; i<$((20-SRV_USAGE/5)); i++)); do printf "░"; done
printf "${RESET} %3d%% ${RESET}\n" "$SRV_USAGE"

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
echo "${GRAY}Live updates: watch -n 5 /srv/openclaw/scripts/dashboard-visual.sh${RESET}"
echo ""
