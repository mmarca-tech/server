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
- Default: `/srv/media/downloads` (container: `/downloads`)
- Incomplete: `/srv/media/downloads/incomplete` (container: `/downloads/incomplete`)
- Radarr category: `/srv/media/downloads/radarr` (auto-created by Radarr)
- Sonarr category: `/srv/media/downloads/sonarr` (auto-created by Sonarr)

> After download completes, Sonarr/Radarr auto-import and move files to
> `/srv/media/series/` or `/srv/media/movies/` respectively.

---

### Jellyseerr (`/srv/server/jellyseerr`)
**Status:** ✅ Running  
**URL:** https://jellyseerr.example.com  
**Port:** 5055 (also accessible on LAN)  
**Docker Compose:** `jellyseerr/docker-compose.yml`

- Media request & discovery UI (browse movies/shows, request downloads)
- Sends movie requests to **Radarr**, TV requests to **Sonarr**
- Integrates with Jellyfin for user auth and library status
- Shows request status and availability

**Pipeline:** Jellyseerr → Sonarr/Radarr → Prowlarr → Transmission → auto-organize → Jellyfin

**Common Issues:**
- Can't find Sonarr/Radarr → Check Settings → Sonarr/Radarr, verify API key and URL (`http://sonarr:8989`, `http://radarr:7878`)
- Requests stuck → Check Sonarr/Radarr activity queue for errors
- Users not syncing → Re-import from Jellyfin in Settings → Users

---

### Sonarr (`/srv/server/sonarr`)
**Status:** ✅ Running  
**Port:** 8989 (LAN only)  
**Docker Compose:** `sonarr/docker-compose.yml`

- TV show management & automation
- Monitors for new episodes, auto-downloads via Transmission
- Moves & renames completed downloads to `/srv/media/series/`
- Integrates with Prowlarr (indexers) and Jellyseerr (requests)

**Media Paths (inside container):**
- Root folder: `/media/series`
- Downloads: `/media/downloads`

**Common Issues:**
- Import failing → Check permissions on `/srv/media/series` (needs PUID 1000)
- Not finding episodes → Check Prowlarr indexer sync
- Quality upgrades not working → Check quality profile cutoff settings

---

### Radarr (`/srv/server/radarr`)
**Status:** ✅ Running  
**Port:** 7878 (LAN only)  
**Docker Compose:** `radarr/docker-compose.yml`

- Movie management & automation
- Monitors for new releases, auto-downloads via Transmission
- Moves & renames completed downloads to `/srv/media/movies/`
- Integrates with Prowlarr (indexers) and Jellyseerr (requests)

**Media Paths (inside container):**
- Root folder: `/media/movies`
- Downloads: `/media/downloads`

**Common Issues:**
- Import failing → Check permissions on `/srv/media/movies` (needs PUID 1000)
- Not finding movies → Check Prowlarr indexer sync
- Wrong quality grabbed → Adjust quality profile

---

### Prowlarr (`/srv/server/prowlarr`)
**Status:** ✅ Running  
**Port:** 9696 (LAN only)  
**Docker Compose:** `prowlarr/docker-compose.yml`

- Indexer manager — single place to configure torrent/usenet indexers
- Auto-syncs indexers to Sonarr and Radarr
- Supports TPB, 1337x, Nyaa, and many more
- Uses FlareSolverr to bypass Cloudflare on protected indexers

**Common Issues:**
- Indexers failing → Check VPN connectivity, indexer may be down
- Cloudflare blocked → Ensure FlareSolverr tag is applied to the indexer
- Not syncing to Sonarr/Radarr → Re-add app connections in Settings → Apps

---

### FlareSolverr (`/srv/server/flaresolverr`)
**Status:** ✅ Running  
**Port:** 8191 (LAN only)  
**Docker Compose:** `flaresolverr/docker-compose.yml`

- Bypasses Cloudflare protection for Prowlarr indexers
- Configured in Prowlarr: Settings → Indexers → Add FlareSolverr proxy (`http://flaresolverr:8191`)
- Apply the FlareSolverr tag to any indexer that gets Cloudflare-blocked

---

### Bazarr (`/srv/server/bazarr`)
**Status:** ✅ Running  
**Port:** 6767 (LAN only)  
**Docker Compose:** `bazarr/docker-compose.yml`

- Automatic subtitle downloads for Sonarr & Radarr
- Supports OpenSubtitles, Addic7ed, Subscene, and many more
- Monitors media libraries and downloads missing subtitles
- Integrates directly with Sonarr and Radarr via API

**Setup:**
1. Settings → Sonarr: `http://sonarr:8989` + API key
2. Settings → Radarr: `http://radarr:7878` + API key
3. Settings → Providers: add subtitle providers (OpenSubtitles, etc.)
4. Settings → Languages: configure desired subtitle languages

**Common Issues:**
- No subtitles found → Add more providers, check language settings
- Wrong subtitles → Adjust anti-false-positive settings, use hearing-impaired filter

---

### Tdarr (`/srv/server/tdarr`)
**Status:** ✅ Running  
**Port:** 8265 (Web UI, LAN only), 8266 (server)  
**Docker Compose:** `tdarr/docker-compose.yml`

- Automatic media transcoding (e.g., H.264 → H.265/HEVC for space savings)
- Monitors media libraries and processes files based on rules
- Built-in node for processing (runs inside the same container)
- Transcode cache at `/srv/tdarr/transcode_cache` (needs fast storage)

**Media Paths (inside container):**
- `/media/movies`, `/media/series`, `/media/music` (same shared mount)

**Setup:**
1. Libraries → Add library → point to `/media/movies` or `/media/series`
2. Transcode options → choose plugins (e.g., "Tiered: H.265, keep quality")
3. Set schedule to avoid transcoding during peak viewing hours

**Common Issues:**
- High CPU during transcode → Set worker limits in Tdarr node settings
- Disk space spikes → Transcode cache needs space for temp files, set cache dir to fast disk
- Quality loss → Use CRF-based encoding, avoid aggressive bitrate targets

---

### Recyclarr (`/srv/server/recyclarr`)
**Status:** ✅ Running (periodic sync)  
**Docker Compose:** `recyclarr/docker-compose.yml`

- Syncs TRaSH Guides quality profiles to Sonarr and Radarr
- Automatically configures optimal custom formats and quality scores
- Runs on schedule (configurable in `recyclarr.yml`)

**Setup:**
1. Copy template: `cp /srv/server/recyclarr/recyclarr.yml.template /srv/recyclarr/config/recyclarr.yml`
2. Edit and add Sonarr/Radarr API keys
3. Manual sync: `docker exec recyclarr recyclarr sync`

**Common Issues:**
- Sync failing → Check API keys and URLs in recyclarr.yml
- Profiles not appearing → Run manual sync, check logs: `docker logs recyclarr`

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

