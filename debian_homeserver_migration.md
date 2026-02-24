# Debian 12 Home Server Migration

> NOTE (current repo layout): the active infrastructure in this repository now uses a split mount design with `/`, `/var/lib/docker`, and `/srv`, and stores app data directly under `/srv/*` (for example `/srv/nextcloud`, `/srv/immich`, `/srv/databases`, `/srv/backups`).  
> For the up-to-date procedure, use `SETUP_GUIDE.md`.

Domain: ivantili.site\
Apps: Nextcloud (MariaDB), Immich (PostgreSQL), Home Assistant (LAN
discovery), Jellyfin, Jellyseerr, Calibre(-Web), Mollysocket\
Target: Docker Compose + Caddy reverse proxy + terminal/ClawdBot
management

------------------------------------------------------------------------

# DNS + Router Configuration

## Router Port Forwarding

Forward to your Debian host: - TCP 80 → 80 - TCP 443 → 443

## DNS Records

Create A records pointing to your WAN IP: - @ → WAN IP - nc → WAN IP -
immich → WAN IP - jellyfin → WAN IP - jellyseerr → WAN IP - calibre →
WAN IP - mollysocket → WAN IP - Optional: ha → WAN IP

------------------------------------------------------------------------

# Debian 12 Host Preparation

## Install Docker + Compose Plugin

``` bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian   $(. /etc/os-release && echo "$VERSION_CODENAME") stable"   | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Log out and back in.

## Enable mDNS for Home Assistant

``` bash
sudo apt install -y avahi-daemon
sudo systemctl enable --now avahi-daemon
```

------------------------------------------------------------------------

# Directory Structure

``` bash
sudo mkdir -p /srv/compose/{proxy,nextcloud,immich,media,ha,jellyseer,jellyfin,calibre,mollysocket}
sudo mkdir -p /srv/data/{caddy,nextcloud,nextcloud-db,immich,immich-db,immich-redis,ha,jellyseer,jellyfin,calibre,mollysocket}
sudo chown -R $USER:$USER /srv/compose /srv/data
```

------------------------------------------------------------------------

# Reverse Proxy (Caddy)

## Create Docker Network

``` bash
docker network create proxy
```

## /srv/compose/proxy/docker-compose.yml

``` yaml
services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    networks:
      - proxy
    volumes:
      - /srv/data/caddy/data:/data
      - /srv/data/caddy/config:/config
      - /srv/compose/proxy/Caddyfile:/etc/caddy/Caddyfile:ro

networks:
  proxy:
    external: true
```

## /srv/compose/proxy/Caddyfile

``` caddy
{
  email you@ivantili.site
}

nc.ivantili.site {
  reverse_proxy nextcloud:80
}

immich.ivantili.site {
  reverse_proxy immich-server:2283
}

jellyfin.ivantili.site {
  reverse_proxy jellyfin:8096
}

jellyseerr.ivantili.site {
  reverse_proxy jellyseerr:5055
}

calibre.ivantili.site {
  reverse_proxy calibre-web:8083
}

mollysocket.ivantili.site {
  reverse_proxy mollysocket:8020
}
```

Start proxy:

``` bash
cd /srv/compose/proxy
docker compose up -d
```

------------------------------------------------------------------------

# Nextcloud (MariaDB)

## docker-compose.yml

``` yaml
services:
  nextcloud-db:
    image: mariadb:11
    container_name: nextcloud-db
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    networks:
      - internal
    volumes:
      - /srv/data/nextcloud-db:/var/lib/mysql
    environment:
      - MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MARIADB_DATABASE=nextcloud
      - MARIADB_USER=nextcloud
      - MARIADB_PASSWORD=${MARIADB_PASSWORD}

  redis:
    image: redis:7-alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    networks:
      - internal

  nextcloud:
    image: nextcloud:29-apache
    container_name: nextcloud
    restart: unless-stopped
    networks:
      - proxy
      - internal
    depends_on:
      - nextcloud-db
      - redis
    volumes:
      - /srv/data/nextcloud/html:/var/www/html
      - /srv/data/nextcloud/data:/var/www/html/data
    environment:
      - MYSQL_HOST=nextcloud-db
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=${MARIADB_PASSWORD}
      - REDIS_HOST=redis

networks:
  proxy:
    external: true
  internal:
    driver: bridge
```

------------------------------------------------------------------------

# Immich (PostgreSQL)

## docker-compose.yml

``` yaml
services:
  immich-db:
    image: postgres:16
    restart: unless-stopped
    volumes:
      - /srv/data/immich-db:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_USER=immich
      - POSTGRES_DB=immich

  immich-redis:
    image: redis:7-alpine
    restart: unless-stopped

  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    restart: unless-stopped
    volumes:
      - /srv/data/immich/library:/usr/src/app/upload
    environment:
      - DB_HOSTNAME=immich-db
      - DB_USERNAME=immich
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_DATABASE_NAME=immich
```

------------------------------------------------------------------------

# Home Assistant (LAN Discovery Enabled)

``` yaml
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    network_mode: host
    volumes:
      - /srv/data/ha:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=Europe/Tallinn
```

------------------------------------------------------------------------

# Management Commands

Update a stack:

``` bash
docker compose pull
docker compose up -d
```

View logs:

``` bash
docker compose logs -f --tail=200
```

------------------------------------------------------------------------

# Deployment

``` bash
git init
git add .
git commit -m "Initial home server infrastructure"
```

Deploy:

``` bash
git clone <repo>
cd proxy && docker compose up -d
cd ../nextcloud && docker compose up -d
```
