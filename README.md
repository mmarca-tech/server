# Debian 12 Home Server Infra

For the complete step-by-step install and security setup, see `SETUP_GUIDE.md`.

This repository contains Docker Compose stacks for:

- Caddy reverse proxy
- Nextcloud (MariaDB + Redis)
- Immich (PostgreSQL + Redis + ML)
- Home Assistant (host networking for LAN discovery)
- Jellyfin
- Jellyseerr
- Calibre-Web
- Mollysocket

And host-native (non-Docker):

- OpenClaw gateway (systemd service)

## 1. Prerequisites on Debian 12

Install Docker Engine + Compose plugin (recommended: repo script with `/srv/docker` data root):

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

Log out/in after adding your user to the docker group.

Enable mDNS for Home Assistant discovery:

```bash
sudo apt install -y avahi-daemon
sudo systemctl enable --now avahi-daemon
```

## 2. Router + DNS

Open and forward ports to this Debian host:

- TCP 80 -> 192.168.1.20:80
- TCP 443 -> 192.168.1.20:443

Create DNS A records to your WAN IP:

- `@`
- `nc`
- `immich`
- `jellyfin`
- `jellyseerr`
- `calibre`
- `mollysocket`
- optional `ha`

## 3. Clone and initialize

```bash
git clone <your-repo-url>
cd server
./scripts/bootstrap-host.sh
./scripts/init-env.sh
```

Then edit all generated `*/.env` files and replace placeholder secrets.
Pin and review each `*_IMAGE` value in those `.env` files before deployment.

Equivalent Make targets:

```bash
make bootstrap
make init
```

Single-command guided setup (with mandatory confirmations at each manual step like router/DNS/env edits):

```bash
./scripts/master-setup.sh
# or
make master-setup
```

Optional: enable public Home Assistant route during master setup:

```bash
EXPOSE_HOMEASSISTANT=true ./scripts/master-setup.sh
```

## 4. Start all stacks

```bash
./scripts/up-all.sh
```

Equivalent Make target:

```bash
make up
```

## 5. Install OpenClaw on the host (non-Docker)

```bash
./scripts/install-openclaw-host.sh
```

This installs OpenClaw globally with `npm`, creates `/etc/openclaw/openclaw.env`, installs `openclaw-gateway` as a systemd service, and starts it.
The systemd unit binds OpenClaw to `loopback` by default (not LAN-exposed), which matches the Telegram-only access model.
OpenClaw runtime files are stored under `/srv/openclaw`.
The installer also ensures `openclaw` has Docker access (`docker` group + systemd supplementary group), so Docker-backed tools work without manual `systemctl edit`.
If OpenClaw was installed earlier, rerun `./scripts/install-openclaw-host.sh` once to apply these service/group fixes.

Then edit:

```bash
sudoedit /etc/openclaw/openclaw.env
sudo systemctl restart openclaw-gateway
```

Run OpenClaw onboarding:

```bash
./scripts/openclaw-onboard.sh
```

Equivalent Make targets:

```bash
make openclaw-install
make openclaw-onboard
```

Use a local small model (instead of OpenAI/cloud) for OpenClaw/ClawdBot:

```bash
./scripts/install-local-llm.sh
./scripts/connect-clawdbot-local.sh
```

Default local model wiring uses alias `gpt-4o-mini` in Ollama and configures OpenClaw model `ollama/gpt-4o-mini`.

Equivalent Make targets:

```bash
make local-llm-install
make clawdbot-local
```

Use OpenAI cloud for OpenClaw/ClawdBot (recommended on low-power hosts):

```bash
OPENAI_API_KEY='sk-...' ./scripts/connect-clawdbot-openai.sh
```

Default cloud model is `openai/gpt-5.2`.

Optional overrides:

```bash
OPENAI_API_KEY='sk-...' MODEL='openai/gpt-5.2-codex' TELEGRAM_DM_POLICY='pairing' ./scripts/connect-clawdbot-openai.sh
```

Equivalent Make target:

```bash
OPENAI_API_KEY='sk-...' make clawdbot-openai
```

Run hardening audit checks:

```bash
./scripts/security-check.sh
make security-check
```

For updates:

```bash
./scripts/pull-all.sh
./scripts/up-all.sh
```

Equivalent Make target sequence:

```bash
make pull
make up
```

## 6. Logs and stop

Tail logs:

```bash
./scripts/logs.sh <stack>
./scripts/logs.sh <stack> <service>
```

Examples:

```bash
./scripts/logs.sh proxy
./scripts/logs.sh nextcloud nextcloud
make logs stack=proxy
```

Stop everything:

```bash
./scripts/down-all.sh
```

Equivalent Make target:

```bash
make down
```

## Repository layout

- `proxy/` Caddy and TLS termination
- `nextcloud/` Nextcloud + MariaDB + Redis
- `immich/` Immich + PostgreSQL + Redis + ML
- `ha/` Home Assistant
- `jellyfin/` Jellyfin media server
- `jellyseerr/` Jellyseerr request manager
- `calibre/` Calibre-Web
- `mollysocket/` Mollysocket
- `openclaw/` OpenClaw host config (`/etc/openclaw/openclaw.env`) + systemd unit template
- `scripts/` operational helpers
- `Makefile` shorthand wrappers around scripts

## Notes

- Recommended host partitions are documented in `SETUP_GUIDE.md` (`/`, `/var`, `/srv` split for your current host).
- Data is persisted under `/srv/*` with this host layout:
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
- All public apps are routed by Caddy over the external Docker network `proxy`.
- OpenClaw is host-native and should not be exposed through Caddy or public DNS.
- Home Assistant runs with `network_mode: host` for LAN discovery.
- To expose Home Assistant through Caddy, run `./scripts/enable-ha-public.sh` (or `make ha-public-enable`).
- The helper script updates `/srv/homeassistant/config/configuration.yaml` with:
```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.16.0.0/12
```
- `scripts/init-env.sh` now syncs newly added keys from `*.env.example` into existing `.env` files.
