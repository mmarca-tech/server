# Service Documentation

All services running on the home server. Each has its own configuration directory.

---

## 📚 Media Services

### Jellyfin (`/srv/server/jellyfin`)
**Status:** ✅ Running  
**URL:** https://jellyfin.example.com  
**Port:** 8096 (exposed directly + via Caddy reverse proxy)  
**Docker Compose:** `jellyfin/docker-compose.yml`

- Stream movies, shows, music, audiobooks
- Auto-library indexing
- Transcoding enabled
- Metadata from The Movie Database / MusicBrainz

**Media Libraries (shared `/srv/media` layout):**
- `/srv/media/series` → `/media/series` (read-only)
- `/srv/media/movies` → `/media/movies` (read-only)
- `/srv/media/music` → `/media/music` (read-only)
- `/srv/media/audiobooks` → `/media/audiobooks` (read-only)

> Replaced Navidrome as the music player. Music is managed/downloaded by Lidarr.

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

### Lidarr (`/srv/server/lidarr`)
**Status:** ✅ Running  
**Port:** 8686 (LAN only)  
**Docker Compose:** `lidarr/docker-compose.yml`

- Music management & automation (equivalent of Sonarr/Radarr for music)
- Monitors artists/albums, auto-downloads via Transmission
- Moves completed downloads to `/srv/media/music/`
- Integrates with Prowlarr (Knaben indexer) and Transmission

**Media Paths (inside container):**
- Root folder: `/media/music`
- Downloads: `/media/downloads`

**Download client:** Transmission via gluetun (`music-lidarr` category)  
**Active indexers:** Knaben (only indexer with full music subcategory support)

**Common Issues:**
- Indexers not syncing from Prowlarr → Only Knaben supports Lidarr's strict music category requirements; others (TPB, 1337x, etc.) only advertise generic `Audio (3000)` which Lidarr rejects
- Import failing → Check permissions on `/srv/media/music` (needs PUID 1000)

---

### Invidious (`/srv/server/invidious`)
**Status:** ✅ Running  
**URL:** https://invidious.example.com  
**Port:** 3000 (internal, via Caddy)  
**Docker Compose:** `invidious/docker-compose.yml`

- Privacy-first YouTube frontend
- No tracking, no ads, no account required for browsing
- Optional user accounts for subscriptions and watch history
- `inv_sig_helper` sidecar handles YouTube signature validation

**Services:**
- `invidious` — main web app (port 3000)
- `inv-sig-helper` — YouTube signature helper (port 12999, internal only)
- `invidious-db` — PostgreSQL database

**Config:** `INVIDIOUS_CONFIG` env var in `docker-compose.yml`  
**Data:** `/srv/invidious/db` (PostgreSQL)

**First run:**
```bash
mkdir -p /srv/invidious/db
cd /srv/server/invidious
cp .env.example .env
# Edit .env: set INVIDIOUS_DOMAIN and generate INVIDIOUS_DB_PASSWORD
# openssl rand -hex 32
docker compose up -d
```

**Common Issues:**
- Videos not playing → Check `inv-sig-helper` is healthy: `docker logs inv-sig-helper`
- Can't reach the site → Verify Caddy reverse_proxy target is `invidious:3000`
- Registration errors → `registration_enabled` is set to `false` by default; enable in compose env if needed
- DB won't start → Check `/srv/invidious/db` ownership: `chown -R 999:999 /srv/invidious/db`

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
- Not finding episodes → Check Prowlarr indexer sync; indexer URLs in Sonarr must use `http://gluetun:9696/...`
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
- Not finding movies → Check Prowlarr indexer sync; indexer URLs in Radarr must use `http://gluetun:9696/...`
- Wrong quality grabbed → Adjust quality profile

---

### Prowlarr (`/srv/server/prowlarr`)
**Status:** ✅ Running  
**Port:** 9696 (LAN only)  
**Docker Compose:** `prowlarr/docker-compose.yml`

- Indexer manager — single place to configure torrent/usenet indexers
- Auto-syncs indexers to Sonarr, Radarr, and Lidarr
- Supports TPB, 1337x, Knaben, and more
- Uses FlareSolverr to bypass Cloudflare on protected indexers

**⚠️ Network note:** Prowlarr shares gluetun's network namespace (`network_mode: service:gluetun`). It has **no `prowlarr` hostname** on `home-network`. Sonarr/Radarr/Lidarr indexer URLs must use `http://gluetun:9696/...` — not `http://prowlarr:9696/...`.

**Current indexers:** 1337x, Elitetorrent, KickassTorrents, Knaben, LimeTorrents, Magnet Cat, The Pirate Bay

**Common Issues:**
- Indexers failing → Check VPN/gluetun connectivity
- Cloudflare blocked → Ensure FlareSolverr tag is applied to the indexer
- Not syncing to apps → Re-add app connections in Settings → Apps; verify URLs use `gluetun` not `prowlarr`

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
1. Generate configs from TRaSH templates:
   `docker exec recyclarr recyclarr config create -t web-1080p -t hd-bluray-web`
2. Edit generated files in `/srv/recyclarr/config/configs/` — set `base_url` and `api_key` for each
3. Sync: `docker exec recyclarr recyclarr sync`
4. List all templates: `docker exec recyclarr recyclarr config list templates`

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

## ⚙️ Automation

### n8n (`/srv/server/n8n`)
**Status:** ✅ Running  
**URL:** https://n8n.example.com  
**Port:** 5678 (internal, via Caddy)  
**Docker Compose:** `n8n/docker-compose.yml`

- Visual workflow automation (Zapier/Make alternative)
- 400+ integrations: webhooks, APIs, databases, messaging
- Self-hosted, no usage limits
- Workflows and credentials stored in SQLite under `/srv/n8n/data`

**Config:** `.env` (host, encryption key, timezone)  
**Data:** `/srv/n8n/data` (SQLite + workflows + credentials)

**First run:**
```bash
mkdir -p /srv/n8n/data
chown -R 1000:1000 /srv/n8n/data   # n8n runs as UID 1000 (node)
cd /srv/server/n8n
cp .env.example .env
# Edit .env: set N8N_HOST and generate N8N_ENCRYPTION_KEY
# openssl rand -hex 32
docker compose up -d
```

**Common Issues:**
- Workflows not saving → Check `/srv/n8n/data` permissions (needs write access by UID 1000)
- Webhooks not firing → Verify `WEBHOOK_URL` matches your public domain
- Can't reach the UI → Check Caddy is routing to `n8n:5678`
- Encryption key changed → All saved credentials will break; keep the key stable

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

## 🔐 Identity & Authentication

### Authelia (`/srv/server/authelia`)
**Status:** ✅ Running  
**URL:** https://auth.ivantili.site  
**Port:** 9091 (internal, via Caddy reverse proxy)  
**Docker Compose:** `authelia/docker-compose.yml`  
**Added:** 2026-03-09

- Self-hosted OIDC/SSO provider
- Flat-file user store (`config/users_database.yml`)
- SQLite storage (`config/db.sqlite3`)
- Two-factor authentication (TOTP)
- Used as identity provider for Tailscale (custom OIDC)
- Private key: `config/oidc.key` (RSA 4096)

**Tailscale OIDC config:**
- Issuer: `https://auth.ivantili.site`
- Client ID: `tailscale`
- Client secret: plaintext saved separately (hashed in config)

**Common Issues:**
- Container won't start → Check `docker logs authelia` for config errors
- Login loop → Clear browser cookies for `auth.ivantili.site`
- TOTP lost → Remove TOTP from DB: `docker exec authelia authelia storage user totp delete --username manu`
- Tailscale auth failing → Verify OIDC discovery: `curl https://auth.ivantili.site/.well-known/openid-configuration`

---

## 📊 Maintenance

- **Daily:** Check error logs (automated)
- **Weekly:** Certificate check, backup verification
- **Monthly:** Clean dangling Docker images, rotate logs
- **Quarterly:** Update all images, security audit

See [INFRASTRUCTURE.md](INFRASTRUCTURE.md) for automation schedule.

