# Transmission Torrent Client

Docker-based torrent client with downloads accessible to Jellyfin, Jellyseerr, Navidrome, and Audiobookshelf.

---

## Quick Start

```bash
cd /srv/server/transmission

# Start
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

---

## Access

### Web UI
- **Local:** http://localhost:9091
- **Remote:** https://transmission.yourdomain.com (via Caddy)

**Default credentials:** admin / (blank password)

---

## Configuration

### Files

- `.env` — Environment variables (image, ports, VPN settings)
- `docker-compose.yml` — Container definition
- `config/` — Transmission settings (persistent)
- `downloads/` — Downloaded files (shared with media services)

### Environment Variables

Edit `.env`:

```bash
# VPN Provider (if using VPN)
OPENVPN_PROVIDER=PIA    # or NordVPN, etc.
OPENVPN_CONFIG=us_seattle
OPENVPN_USERNAME=your_vpn_username
OPENVPN_PASSWORD=your_vpn_password
DISABLE_VPN=false
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

---

## Download Organization

Transmission saves files to `/downloads` inside the container, which maps to:

```
/srv/server/transmission/downloads/
├── .incomplete/        # Incomplete downloads
├── movies/            # Movies (mount to Jellyfin)
├── tv/                # TV Shows (mount to Jellyseerr)
├── music/             # Music (mount to Navidrome)
├── audiobooks/        # Audiobooks (mount to Audiobookshelf)
└── [other files]
```

### Media Service Access

Each service can access downloads:

- **Jellyfin:** `/downloads` or `/movies` → `/downloads`
- **Jellyseerr:** `/downloads` or `/tv` → `/downloads`
- **Navidrome:** `/downloads/music` → `/music`
- **Audiobookshelf:** `/downloads/audiobooks` → `/audiobooks`

---

## Common Tasks

### Change Download Location

Edit `docker-compose.yml`:

```yaml
volumes:
  - ./downloads:/downloads  # Change './downloads' to new path
```

Restart:
```bash
docker-compose down
docker-compose up -d
```

### Enable VPN

1. Edit `.env`:
   ```bash
   DISABLE_VPN=false
   OPENVPN_PROVIDER=PIA
   OPENVPN_CONFIG=us_seattle
   OPENVPN_USERNAME=your_username
   OPENVPN_PASSWORD=your_password
   ```

2. Restart:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

3. Verify:
   ```bash
   docker logs transmission_fresh-transmission-1 | grep -i vpn
   ```

### Check Download Speed

```bash
docker stats transmission_fresh-transmission-1
```

### Backup Settings

```bash
tar -czf transmission-backup.tar.gz config/
```

---

## Ports

- **6969** — Torrent peer listening port (TCP/UDP)
- **9091** — Web UI (TCP, only via Caddy externally)

---

## Troubleshooting

### Cannot access web UI

```bash
# Check if container is running
docker ps | grep transmission

# Check logs
docker logs transmission_fresh-transmission-1

# Verify port is open
ss -ltn | grep 9091
```

### Downloads not showing in Jellyfin/Navidrome

1. Check permissions:
   ```bash
   ls -la /srv/server/transmission/downloads/
   ```

2. Verify mounts in each service's docker-compose.yml

3. Ensure media service has read access to downloads

### Very slow speeds

- Check network (may be VPN limitation)
- Check system load: `docker stats`
- Disable VPN if enabled
- Check throttle settings in Transmission UI

---

## Notes

- **No VPN by default** — Set `DISABLE_VPN=false` in `.env` to enable
- **Web UI password** — Set in `config/settings.json` or Transmission UI
- **Legal use only** — Only use for legal torrent downloads (Linux distros, Creative Commons, etc.)

