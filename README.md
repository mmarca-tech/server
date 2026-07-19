# Debian 12 AlphaVPS Infrastructure

This repository deploys a Docker Compose service stack on a fresh Debian 12
x86_64 VPS. Caddy is the only public application entry point; administration
interfaces are reachable only through WireGuard.

## Quick start

```bash
sudo install -m 0600 config/deploy.env.example /root/server.env
sudoedit /root/server.env
sudo DEPLOY_CONFIG=/root/server.env ./scripts/deploy.sh --check
sudo DEPLOY_CONFIG=/root/server.env ./scripts/deploy.sh
```

The deployment is idempotent. If an interrupted run needs to skip completed
stages, rerun it with `--resume`.

The full profile requires fresh ProtonVPN credentials, an Authelia password
hash, explicit lawful-use and dedicated-CPU acknowledgements, and sufficient
VPS capacity. Use `DEPLOY_PROFILE=core` to omit private media and LAN-oriented
services.

## Security model

- Public ports: key-only SSH, HTTP/HTTPS, HTTP/3, and WireGuard.
- The configured SSH administrator has passwordless sudo; possession of that
  private SSH key is equivalent to root access and must be protected.
- Public applications: Nextcloud, Immich, Jellyfin, Seerr, Calibre-Web,
  Audiobookshelf, and Authelia through Caddy, plus a self-hosted Gitea (with
  Gitea Actions) on its own domain.
- Private applications: media automation, AdGuard, and download administration
  through the WireGuard address.
- Databases, caches, browser workers, and support containers are internal-only.
- A Woodpecker CI agent attaches outbound to Codeberg's hosted instance; it has
  no inbound exposure but mounts the Docker socket to run pipeline steps.
- Secrets are stored under `/etc/server-infra`, never in this repository.

## Documentation

- [Deployment](DEPLOYMENT.md)
- [Services and access](SERVICES.md)
- [Operations](OPS_CHEAT_SHEET.md)
- [Pinned versions](VERSIONS.md)
- [Claude Cowork workflow](CLAUDE_COWORK.md)
