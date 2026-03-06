# Service Documentation

All services running on the home server. Each has its own configuration directory.

---

## 📚 Media Services

### Jellyfin (`/srv/server/jellyfin`)
**Status:** ✅ Running  
**URL:** https://jellyfin.example.com  
**Port:** 8096 (exposed directly + via Caddy reverse proxy)  
**Docker Compose:** `jellyfin/docker-compose.yml`

- Stream movies, shows, music
- Auto-library indexing
- Transcoding enabled
- Metadata from The Movie Database

**Media Libraries (shared `/srv/media` layout):**
- `/srv/media/series` → `/media/series` (read-only)
- `/srv/media/movies` → `/media/movies` (read-only)
- `/srv/media/music` → `/media/music` (read-only)
- `/srv/media/audiobooks` → `/media/audiobooks` (read-only)

> Previously used a single `/srv/jellyfin/media` mount. Now shares the centralised `/srv/media` tree with other services (Navidrome, Audiobookshelf, Transmission downloads).

**Common Issues:**
- Indexing slow → Check storage I/O, reduce scan frequency
- Transcoding buffering → Check network bandwidth, reduce bitrate
- Library not updating → Restart container: `docker restart jellyfin`

**Admin Panel:** http://localhost:8096 (local network only)

---

### Immich (`/srv/server/immich`)
**Status:** ✅ Running  
**URL:** https://immich.example.com  
**Docker Compose:** `immich/docker-compose.yml`

- Photo/video library with ML indexing
- Object detection (faces, scenes)
- Auto-backup from phone
- Sharing & albums

**Common Issues:**
- ML processing slow → Check GPU/CPU, may take hours on first run
- Search not working → Rebuild index: admin panel → Maintenance
- Photos not uploading → Check mobile app permissions
- Database bloated → Monthly cleanup needed (script planned)

**Services:**
- `immich-server` (API)
- `immich-machine-learning` (indexing)
- `immich-db` (PostgreSQL)
- `immich-redis` (cache)

---

### Navidrome (`/srv/server/navidrome`)
**Status:** ✅ Running  
**URL:** https://navidrome.example.com  
**Port:** 4533  
**Docker Compose:** `navidrome/docker-compose.yml`

- Music streaming (Subsonic-compatible)
- FLAC, MP3, AAC support
- Playlist sync to clients
- Scrobbling support

**Common Issues:**
- Library not scanning → `docker logs navidrome`
- Slow initial scan → First scan can take hours (depends on library size)
- Transcoding issues → Check available disk space

---

### Calibre (`/srv/server/calibre`)
**Status:** ✅ Running  
**URL:** https://calibre.example.com  
**Port:** 8083  
**Docker Compose:** `calibre/docker-compose.yml`

- E-book library management
- Format conversion
- EPUB/PDF/MOBI support

**Common Issues:**
- Books not showing → Refresh library: UI → Restart
- Conversion errors → Check source format, see Docker logs

---

### Transmission (`/srv/server/transmission`)
**Status:** ✅ Running  
**URL:** https://transmission.example.com  
**Port:** 9091 (Web UI), 6969 (peer), 51413 (peer)  
**Docker Compose:** `transmission/docker-compose.yml`

- Torrent download client
- Web-based UI
- Remote control via `transmission-remote`
- Integrated with OpenClaw for Telegram-based search & download
- **VPN:** All traffic routed through ProtonVPN via gluetun (WireGuard)
- **Port forwarding:** Enabled via ProtonVPN NAT-PMP for better peer connectivity

**VPN Details (gluetun sidecar):**
- Provider: ProtonVPN (WireGuard)
- Server region: Estonia
- Port forwarding: ✅ Enabled (`VPN_PORT_FORWARDING=on`, `PORT_FORWARD_ONLY=on`)
- Transmission network mode: `network_mode: "service:gluetun"` (all traffic goes through VPN)
- Config: `transmission/gluetun/` (servers.json cached locally)
- Backup: `transmission/docker-compose.yml.bak` (pre-VPN config)

**Download Directories:**
- Movies: `/srv/media/downloads/movies`
- TV: `/srv/media/downloads/tv`
- General: `/srv/media/downloads`

**Torrent Search Script:** `scripts/torrent-search.sh`
- Search torrents from Telegram via OpenClaw
- Sources: TPB, 1337x, Nyaa
- Auto-sends magnet links to Transmission
- Usage: Ask the OpenClaw agent to "search for [query] torrent"

**Commands:**
```bash
# List active torrents
transmission-remote 127.0.0.1:9091 --list

# Add magnet via CLI
transmission-remote 127.0.0.1:9091 --add "magnet:?..."

# Search via script
./scripts/torrent-search.sh search "query"
./scripts/torrent-search.sh download "magnet:?..." /srv/media/downloads/movies
./scripts/torrent-search.sh status
```

**Common Issues:**
- Port blocked → Check firewall: `ss -ltn | grep 9091`
- Slow downloads → Check peer port (6969/51413) is open on router
- Can't add torrent → Verify transmission-remote: `which transmission-remote`

---

## 🏠 Smart Home

### Home Assistant (`/srv/server/ha`)
**Status:** ✅ Running  
**URL:** http://homeassistant:8123 (internal) / https://ha.example.com (external)  
**Docker Compose:** `ha/docker-compose.yml`

- Home automation hub
- Integration with 100+ devices
- Automations & scenes
- Local voice control

**Token:** `~/.openclaw/.ha_token` (for API access from OpenClaw)

**Common Issues:**
- Integrations disconnecting → Check network connectivity, restart integration
- Database corrupted → Restore from backup
- UI slow → Reduce number of history days

**Admin Panel:** http://homeassistant:8123

---

### MollySocket (`/srv/server/mollysocket`)
**Status:** ✅ Running  
**Port:** Internal only  
**Docker Compose:** `mollysocket/docker-compose.yml`

- Signal messaging relay
- Private chat backups

---

## 💼 Productivity & Files

### Nextcloud (`/srv/server/nextcloud`)
**Status:** ✅ Running  
**URL:** https://nc.example.com  
**Docker Compose:** `nextcloud/docker-compose.yml`

- File sync & sharing
- Calendar & contacts
- Email
- Notes & tasks

**Services:**
- `nextcloud` (Apache web server)
- `nextcloud-db` (MariaDB)
- `nextcloud-redis` (cache)

**Common Issues:**
- Files not syncing → Check desktop client logs
- Slow uploads → Check network, verify database isn't full
- Database errors → Check disk space: `df -h`

**Admin Panel:** https://nc.example.com/settings/admin

---

## 🛡️ Infrastructure

### AdGuard (`/srv/server/adguard`)
**Status:** ✅ Running  
**DNS:** 192.168.1.20:53  
**Admin UI:** https://192.168.1.20:3001 (LAN only)  
**Docker Compose:** `adguard/docker-compose.yml`

- Network-wide ad blocking
- DNS filtering
- Parental controls

**Config:** `/srv/server/adguard/conf/AdGuardHome.yaml`

**Common Issues:**
- DNS not resolving → Check port 53: `ss -ltn | grep :53`
- Ads still showing → Check filter lists are enabled
- High CPU → Reduce number of clients, disable deep inspection

---

### Caddy (`/srv/server/proxy`)
**Status:** ✅ Running  
**HTTP:** 0.0.0.0:80  
**HTTPS:** 0.0.0.0:443  
**Admin API:** 127.0.0.1:2019  
**Docker Compose:** `proxy/docker-compose.yml`

- Reverse proxy
- Automatic HTTPS with Let's Encrypt
- Request logging
- Compression & security headers

**Config:** `/srv/server/proxy/Caddyfile`

**Common Issues:**
- Certificate not renewing → Check ACME logs: `docker logs caddy | grep -i acme`
- Services not accessible → Check Caddyfile reverse_proxy targets
- 502 Bad Gateway → Check target service is running

**Reload config:** `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`

---

## 🗂️ Adding New Services

1. Create directory: `/srv/server/SERVICE_NAME`
2. Add `docker-compose.yml`
3. Add to Caddyfile if web-accessible
4. Document in this file
5. Commit: `./scripts/git-auto-commit.sh "Add SERVICE_NAME"`

**Template:**
```yaml
version: '3.8'
services:
  service:
    image: example:latest
    container_name: example
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./config:/config
    environment:
      - TZ=Europe/Tallinn
networks:
  default:
    name: home-network
```

---

## 📊 Maintenance

- **Daily:** Check error logs (automated)
- **Weekly:** Certificate check, backup verification
- **Monthly:** Clean dangling Docker images, rotate logs
- **Quarterly:** Update all images, security audit

See [INFRASTRUCTURE.md](INFRASTRUCTURE.md) for automation schedule.

