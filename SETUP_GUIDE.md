# Home Server Setup Guide (Debian 12)

This guide configures your server so apps are reachable only via subdomains of `ivantili.site`, while OpenClaw is host-native and not publicly reachable.

## 0. Preflight (Do This First)

1. Reserve/set static LAN IP `192.168.1.20` for the Debian host in your router DHCP settings.
2. Confirm Debian host has correct timezone and NTP sync:

```bash
timedatectl
```

3. Confirm you can SSH using keys before hardening SSH config.
4. Confirm your DNS provider allows creating `A` records for `ivantili.site`.
5. Confirm your router supports NAT loopback/hairpin NAT, or plan local DNS overrides for LAN clients.

Verify the host has the expected LAN address:

```bash
ip -4 addr | rg -n '192\\.168\\.1\\.20'
```

### 0.1 Recommended single-disk partition layout

Use this host layout:

| Device | Size | Filesystem | Mount Point | Purpose |
|---|---:|---|---|---|
| `nvme0n1p1` | 976 MB | vfat | `/boot/efi` | UEFI boot |
| `nvme0n1p2` | 30.3 GB | ext4 | `/` | Debian OS |
| `nvme0n1p3` | 12.1 GB | ext4 | `/var` | System variable data (includes Docker root by default) |
| `nvme0n1p4` | 977 MB | swap | `[SWAP]` | Swap |
| `nvme0n1p5` | 432.5 GB | ext4 | `/srv` | Persistent app data and backups |

Current `lsblk` reference:

```text
NAME          SIZE FSTYPE TYPE MOUNTPOINTS
sda             0B        disk
nvme0n1     476.9G        disk
├─nvme0n1p1   976M vfat   part /boot/efi
├─nvme0n1p2  30.3G ext4   part /
├─nvme0n1p3  12.1G ext4   part /var
├─nvme0n1p4   977M swap   part [SWAP]
└─nvme0n1p5 432.5G ext4   part /srv
```

Notes:

- App volumes from this repo are stored under `/srv/*`.
- Docker image/layer storage is under `/var/lib/docker` unless explicitly moved.
- Because `/var` is 12.1 GB, monitor Docker image usage regularly.

Target `/srv` tree used by this repo:

```text
/srv/
 ├── proxy/
 ├── nextcloud/
 ├── immich/
 ├── jellyfin/
 ├── jellyseerr/
 ├── calibre/
 ├── mollysocket/
 ├── homeassistant/
 ├── databases/
 └── backups/
```

Create/mount those partitions during Debian installation (manual partitioning), then verify:

```bash
findmnt / /var /srv /boot/efi
```

### 0.2 Optional: move Docker root to `/srv/docker` (recommended with `/var=12.1G`)

Because `/var` is only `12.1G`, Docker images can fill it quickly.  
The installer script in section `1.2` already does this.  
Manual process (if you need it separately):

```bash
sudo systemctl stop docker docker.socket containerd
sudo mkdir -p /srv/docker
sudo rsync -aHAX --delete /var/lib/docker/ /srv/docker/
sudo mv /var/lib/docker /var/lib/docker.bak
sudo mkdir -p /etc/docker
```

Create `/etc/docker/daemon.json`:

```bash
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "data-root": "/srv/docker"
}
EOF
```

Restart Docker and verify:

```bash
sudo systemctl start containerd docker
docker info | rg -n 'Docker Root Dir'
```

After confirming `Docker Root Dir: /srv/docker`:

```bash
sudo rm -rf /var/lib/docker.bak
```

## 1. Installation

### 1.1 Base OS updates

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

After reboot, reconnect and continue.

### 1.2 Install Docker and Compose plugin

Preferred (from this repo, configures Docker data root to `/srv/docker`):

```bash
./scripts/install-docker-host.sh
```

Equivalent Make target:

```bash
make docker-install
```

Manual alternative:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Log out and log back in after docker group changes.

### 1.3 Enable mDNS for Home Assistant discovery

```bash
sudo apt install -y avahi-daemon
sudo systemctl enable --now avahi-daemon
```

### 1.4 Clone and bootstrap this repo

```bash
git clone <your-repo-url>
cd server
./scripts/bootstrap-host.sh
./scripts/init-env.sh
```

Edit all generated `*/.env` files and set strong secrets.
Also review and pin all `*_IMAGE` variables to versions you have tested.
`bootstrap-host.sh` creates the `/srv/*` directory layout shown above.

### 1.5 Install OpenClaw on host (non-Docker)

```bash
./scripts/install-openclaw-host.sh
sudoedit /etc/openclaw/openclaw.env
sudo systemctl restart openclaw-gateway
./scripts/openclaw-onboard.sh
```

The installed `openclaw-gateway` systemd unit binds to `loopback` by default to keep it host-local.
OpenClaw runtime data is stored in `/srv/openclaw` (not `/var/lib/openclaw`) to avoid filling the small `/var` partition.

### 1.6 Optional: local small model for OpenClaw/ClawdBot

Install local model runtime and pull a small model:

```bash
./scripts/install-local-llm.sh
```

Connect OpenClaw to local OpenAI-compatible endpoint (`127.0.0.1:11434`):

```bash
./scripts/connect-clawdbot-local.sh
```

You can override model/base URL when needed:

```bash
BASE_MODEL=llama3.2:3b MODEL_ALIAS=openai/llama3.2:3b ./scripts/install-local-llm.sh
MODEL=openai/llama3.2:3b BASE_URL=http://127.0.0.1:11434/v1 ./scripts/connect-clawdbot-local.sh
```

Equivalent Make targets:

```bash
make local-llm-install
make clawdbot-local
```

## 2. Proxy Setup (Caddy)

### 2.1 Configure domain variables

Edit `proxy/.env`:

- `ACME_EMAIL=you@ivantili.site`
- `ROOT_DOMAIN=ivantili.site`

### 2.2 Keep only app routes in Caddy

`proxy/Caddyfile` should include app routes such as:

- `nc.ivantili.site`
- `immich.ivantili.site`
- `jellyfin.ivantili.site`
- `jellyseerr.ivantili.site`
- `calibre.ivantili.site`
- `mollysocket.ivantili.site`

OpenClaw route must not exist in Caddy.

### 2.3 Start services

```bash
./scripts/up-all.sh
```

### 2.4 Verify Caddy and TLS

```bash
./scripts/logs.sh proxy
curl -I https://nc.ivantili.site
curl -I https://immich.ivantili.site
```

Confirm Caddy header hardening is active:

```bash
curl -I https://nc.ivantili.site | rg -n 'strict-transport-security|x-content-type-options|x-frame-options' -i
```

## 3. Router + Firewall Ports

### 3.1 Router port forwards (only these)

- TCP `80` -> `192.168.1.20:80`
- TCP `443` -> `192.168.1.20:443`

Do not forward OpenClaw or app backend ports.

### 3.2 Host firewall hardening (UFW)

```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
sudo ufw deny 18789/tcp
sudo ufw deny 18790/tcp
sudo ufw enable
sudo ufw status verbose
```

If your LAN subnet differs from `192.168.1.0/24`, adjust that SSH rule accordingly.

## 4. DNS Setup for ivantili.site

Create `A` records pointing to your WAN IP:

- `@`
- `nc`
- `immich`
- `jellyfin`
- `jellyseerr`
- `calibre`
- `mollysocket`
- optional `ha`

Do not create any DNS record for OpenClaw.

After creating DNS records, verify propagation:

```bash
dig +short nc.ivantili.site
dig +short immich.ivantili.site
dig +short jellyfin.ivantili.site
```

## 5. Host Hardening

### 5.1 SSH hardening

1. Edit `/etc/ssh/sshd_config` and set:
- `PasswordAuthentication no`
- `PermitRootLogin no`

2. Restart SSH:

```bash
sudo systemctl restart ssh
```

3. Keep at least one active SSH session open while testing a new login.

### 5.2 Automatic security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 5.3 Fail2ban

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

## 6. Secrets and File Permissions

1. Use long random passwords/tokens in all `*/.env` files.
2. Protect env files:

```bash
chmod 600 */.env
sudo chown root:openclaw /etc/openclaw/openclaw.env
sudo chmod 640 /etc/openclaw/openclaw.env
```

3. Never commit secret values to git.

## 7. Service Post-Setup Checks

### 7.1 Nextcloud

1. Complete first-run web setup at `https://nc.ivantili.site`.
2. In Nextcloud settings, ensure Redis/file locking and DB are healthy.
3. Optional: switch background jobs from AJAX to Cron.

### 7.2 Immich

1. Open `https://immich.ivantili.site`.
2. Confirm upload works and machine learning jobs run.
3. Check logs for DB/Redis/ML connectivity:

```bash
./scripts/logs.sh immich
```

### 7.3 Jellyfin / Jellyseerr / Calibre / Mollysocket

1. Confirm each app is reachable via HTTPS subdomain.
2. Confirm media/library paths are mounted and readable where required.

## 8. OpenClaw Telegram-Only Access Policy

To keep OpenClaw accessible only through Telegram chat integrations:

1. Run OpenClaw as host service (`openclaw-gateway`), not Docker.
2. Do not create `claw.ivantili.site` DNS.
3. Do not add an OpenClaw route in `proxy/Caddyfile`.
4. Do not forward router ports `18789` or `18790`.
5. Keep firewall deny rules for `18789/tcp` and `18790/tcp`.
6. Verify from an external network that ports `18789/18790` are closed.

## 9. Backups and Restore

### 9.1 What to back up

- `/srv/`
- Repository files in this project
- `/etc/openclaw/openclaw.env`

### 9.2 Example backup command

```bash
sudo rsync -aH --delete /srv/ /path/to/backup/srv/
sudo rsync -aH --delete /etc/openclaw/ /path/to/backup/etc-openclaw/
rsync -aH --delete /home/<user>/server/ /path/to/backup/repo/
```

### 9.3 Schedule

- Daily incremental backups
- Weekly full backups
- Quarterly restore test to a staging machine or temp VM

## 10. Operations Runbook

### 10.1 Update routine

```bash
./scripts/pull-all.sh
./scripts/up-all.sh
```

### 10.2 Logs

```bash
./scripts/logs.sh <stack>
./scripts/logs.sh <stack> <service>
```

### 10.3 Stop all stacks

```bash
./scripts/down-all.sh
```

### 10.4 OpenClaw service checks

```bash
sudo systemctl status openclaw-gateway
sudo journalctl -u openclaw-gateway -n 200 --no-pager
```

### 10.5 Disk and cleanup

```bash
df -h
docker system df
```

If needed:

```bash
docker image prune -f
```

### 10.6 Security audit script

Run after any infrastructure change:

```bash
./scripts/security-check.sh
```

Override defaults if you ever change LAN addressing:

```bash
LAN_IP=192.168.1.20 LAN_CIDR=192.168.1.0/24 ./scripts/security-check.sh
```

## 11. Final Validation Checklist

1. DNS resolves correctly for all intended app subdomains.
2. Router forwards only `80` and `443`.
3. UFW active and denies `18789/18790`.
4. All public apps load via HTTPS and valid certificates.
5. No OpenClaw route exists in `proxy/Caddyfile`.
6. No OpenClaw DNS record exists.
7. OpenClaw accessible only via your Telegram chat workflow.
8. Backups run successfully and at least one restore test has been completed.
9. `./scripts/security-check.sh` returns zero failures.
