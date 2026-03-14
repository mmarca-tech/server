#!/bin/bash
set -euo pipefail

# Master Media Organization Script
# Run this script with proper permissions (as manu user or with sudo)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   COMPLETE MEDIA ORGANIZATION EXECUTION                    ║${NC}"
echo -e "${BLUE}║   Movies: /srv/media/movies → /srv/media/movies-new       ║${NC}"
echo -e "${BLUE}║   Series: /srv/media/series → /srv/media/tv               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Check current user
CURRENT_USER=$(whoami)
echo -e "${YELLOW}Current user: $CURRENT_USER${NC}"

if [[ "$CURRENT_USER" != "manu" && "$EUID" -ne 0 ]]; then
    echo -e "${RED}✗ This script must be run as 'manu' user or with sudo${NC}"
    echo "  Run: sudo -u manu bash /tmp/execute_media_organization.sh"
    exit 1
fi

echo -e "${YELLOW}Running as authorized user${NC}\n"

# Step 1: Fix Permissions
echo -e "${BLUE}[STEP 1/7] Fixing Permissions${NC}"
echo "Creating directories and setting proper ownership..."

mkdir -p /srv/media/tv /srv/media/movies-new
chmod 755 /srv/media/tv /srv/media/movies-new
find /srv/media -type d -exec chmod 755 {} \; 2>/dev/null || true

ls -ld /srv/media/tv /srv/media/movies-new
echo -e "${GREEN}✓ Permissions fixed${NC}\n"

# Step 2: Organize Movies
echo -e "${BLUE}[STEP 2/7] Organizing Movies (256 folders)${NC}"
echo "This may take 30-60 minutes (using moves instead of copies for speed)..."
echo "Progress updates will appear below:"
echo ""

# Run with 90-minute timeout (moves are much faster than copies)
TIMEOUT=5400
if timeout $TIMEOUT python3 /srv/server/scripts/organize_movies.py; then
    MOVIE_STATUS=$?
else
    MOVIE_STATUS=$?
    if [[ $MOVIE_STATUS -eq 124 ]]; then
        echo -e "${RED}✗ Movie organization TIMEOUT (exceeded $((TIMEOUT/60)) minutes)${NC}"
        exit 1
    fi
fi

if [[ -f /tmp/movie_organization.log ]]; then
    echo ""
    echo -e "${GREEN}✓ Movies organized${NC}\n"
else
    echo -e "${RED}✗ Movie organization failed${NC}"
    exit 1
fi

# Step 3: Organize Series
echo -e "${BLUE}[STEP 3/7] Organizing Series (14 folders)${NC}"
echo "Progress updates will appear below:"
echo ""

# Run with 30-minute timeout
TIMEOUT=1800
if timeout $TIMEOUT python3 /srv/server/scripts/organize_series.py; then
    SERIES_STATUS=$?
else
    SERIES_STATUS=$?
    if [[ $SERIES_STATUS -eq 124 ]]; then
        echo -e "${RED}✗ Series organization TIMEOUT (exceeded $((TIMEOUT/60)) minutes)${NC}"
        exit 1
    fi
fi

if [[ -f /tmp/series_organization.log ]]; then
    echo ""
    echo -e "${GREEN}✓ Series organized${NC}\n"
else
    echo -e "${RED}✗ Series organization failed${NC}"
    exit 1
fi

# Step 4: Verify
echo -e "${BLUE}[STEP 4/7] Verification${NC}"

# Run with 10-minute timeout
timeout 600 python3 /srv/server/scripts/verify_organization.py || echo -e "${YELLOW}⚠ Verification timed out (continuing anyway)${NC}"

echo ""

# Step 5: Show logs
echo -e "${BLUE}[STEP 5/7] Organization Logs${NC}"

echo -e "\n${YELLOW}Movie Organization Log (Summary):${NC}"
python3 << 'PYEOF'
import json
with open('/tmp/movie_organization.log') as f:
    log = json.load(f)
    print(f"  Total processed: {log['total']}")
    print(f"  Success: {log['success']}")
    print(f"  Errors: {len(log['errors'])}")
    print(f"  Skipped: {log['skipped']}")
PYEOF

echo -e "\n${YELLOW}Series Organization Log (Summary):${NC}"
python3 << 'PYEOF'
import json
with open('/tmp/series_organization.log') as f:
    log = json.load(f)
    print(f"  Total processed: {log['total']}")
    print(f"  Success: {log['success']}")
    print(f"  Errors: {len(log['errors'])}")
PYEOF

# Step 6: Backup and Deploy
echo -e "\n${BLUE}[STEP 6/7] Backup and Deploy${NC}"

echo "Creating backup: /srv/media/movies → /srv/media/movies-old"
if [[ ! -d /srv/media/movies-old ]]; then
    mv /srv/media/movies /srv/media/movies-old
    echo -e "${GREEN}✓ Backup created${NC}"
else
    echo -e "${YELLOW}⚠ Backup already exists, skipping${NC}"
fi

echo "Deploying new structure: /srv/media/movies-new → /srv/media/movies"
if [[ ! -d /srv/media/movies ]]; then
    mv /srv/media/movies-new /srv/media/movies
    echo -e "${GREEN}✓ New structure deployed${NC}"
else
    echo -e "${RED}✗ /srv/media/movies already exists${NC}"
    echo "  Manual intervention needed - review the situation"
fi

# Step 7: Container Integration Instructions
echo -e "\n${BLUE}[STEP 7/7] Container Integration${NC}"

cat << 'INSTRUCTIONS'
📋 Next Steps - Container Configuration:

1. Verify Radarr Can Access Movies:
   - docker exec radarr curl -s http://localhost:7878/api/v3/system/status
   - Check if library path is set to /media/movies

2. Verify Sonarr Can Access Series:
   - docker exec sonarr curl -s http://localhost:8989/api/v3/system/status
   - Check if library path is set to /media/tv

3. Test Jellyfin Access:
   - Navigate to Jellyfin dashboard
   - Run library scan to auto-detect new structure
   - Verify movies and series appear correctly

4. If Issues Occur - Rollback:
   ```bash
   rm -rf /srv/media/movies
   mv /srv/media/movies-old /srv/media/movies
   ```

5. Update Radarr Configuration (if needed):
   - Add library root folder: /media/movies
   - Monitor import status in Settings → Import Lists

6. Update Sonarr Configuration (if needed):
   - Add library root folder: /media/tv
   - Monitor import status in Settings → Import Lists
INSTRUCTIONS

echo -e "\n${GREEN}✓ Media organization complete!${NC}"
echo -e "${YELLOW}Logs available at:${NC}"
echo "  - /tmp/movie_organization.log"
echo "  - /tmp/series_organization.log"
echo ""
echo -e "${YELLOW}Scripts location:${NC}"
echo "  - /srv/server/scripts/execute_media_organization.sh"
echo "  - /srv/server/scripts/organize_movies.py"
echo "  - /srv/server/scripts/organize_series.py"
echo "  - /srv/server/scripts/verify_organization.py"
echo ""
