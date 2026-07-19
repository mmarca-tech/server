# Deployment Guide

## 1. Prepare AlphaVPS and DNS

Use a fresh Debian 12 x86_64 instance. The full profile is intended for a VPS
with at least 8 dedicated vCPUs and roughly 16 GB RAM. AlphaVPS prohibits
illegal content and sustained CPU/I/O-heavy use on plans without dedicated
cores; the deployment requires explicit acknowledgements instead of assuming
permission.

Create A records pointing to `PUBLIC_IPV4` for:

```text
@ nc immich hometheater seerr calibre audiobookshelf auth
```

Gitea is served on its own domain (`GITEA_DOMAIN`), so also create an A record
for it — pointing at the same `PUBLIC_IPV4`. If it is under a different apex
than `ROOT_DOMAIN` (for example `git.mmarca.tech`), create the record in that
zone. Preflight verifies `GITEA_DOMAIN` resolves too.

Do not create AAAA records unless the VPS IPv6 address is configured and
declared in `PUBLIC_IPV6`. DNS is verified by preflight but is not modified.

## 2. Create the root-only configuration

```bash
sudo install -m 0600 config/deploy.env.example /root/server.env
sudoedit /root/server.env
```

Replace every placeholder. Rotate the ProtonVPN WireGuard credential that was
previously committed. Generate the Authelia password hash using a trusted
Authelia installation and put only the hash in the configuration.

For the full profile, set both acknowledgements to `true`. Set
`ALLOW_LOW_RESOURCES=true` only when consciously overriding the capacity gate.

## 3. Preflight and deploy

```bash
sudo DEPLOY_CONFIG=/root/server.env ./scripts/deploy.sh --check
sudo DEPLOY_CONFIG=/root/server.env ./scripts/deploy.sh
```

The command performs these ordered stages:

1. Validate OS, architecture, configuration permissions, DNS, resources,
   credentials, and ports.
2. Update Debian and install security, WireGuard, and monitoring packages.
3. Install Docker Engine, Buildx, and Compose from Docker's Debian repository.
4. Create the administrator, enforce key-only SSH, and enable fail2ban.
5. Generate WireGuard server/client keys and enable the private network.
6. Enable UFW and the Docker forwarding policy.
7. Generate root-only service secrets and persistent `/srv` directories.
8. Render every Compose project and validate Caddy.
9. Build/start the selected stacks, wait for health, and install monitoring.
10. Run runtime exposure and health verification.

Completed stages are recorded in `/var/lib/server-infra/deploy.state`. To
continue an interrupted deployment without rerunning successful stages:

```bash
sudo DEPLOY_CONFIG=/root/server.env ./scripts/deploy.sh --resume
```

## 4. Connect to private services

From the administrator workstation, retrieve the generated client
configuration securely:

```bash
ssh serveradmin@PUBLIC_IPV4 'sudo cat /etc/server-infra/wireguard-admin.conf' > wireguard-admin.conf
chmod 600 wireguard-admin.conf
```

Replace the username/client filename if configured differently, then import it
into a WireGuard client. Private service URLs use `10.66.0.1` by
default; see [SERVICES.md](SERVICES.md). The client configuration routes only
the administration subnet, not general internet traffic.

## 5. Recovery

- SSH remains public, key-only, and fail2ban-protected to avoid a VPN lockout.
- If a stack fails, inspect it with `scripts/stack.sh logs STACK` and rerun
  deployment with `--resume` after correcting the cause.
- If the firewall service fails, use the AlphaVPS console, run `ufw disable`,
  correct `/etc/server-infra/deploy.env`, and rerun the firewall service.
- Generated application passwords are in `/etc/server-infra/secrets.env` with
  root-only permissions.
- Backups are created under `/srv/backups` with `scripts/stack.sh backup`.
- The built-in backup captures configuration, application state, and logical
  database dumps. Large `/srv/media` libraries require separate off-site or
  snapshot-based backup coverage. It briefly stops application containers,
  keeps only database containers online for logical dumps, then restores the
  full stack before returning.
- Restore a verified backup with
  `scripts/stack.sh restore /srv/backups/server-infra-TIMESTAMP --confirm`.
  The command stops the stack, verifies checksums, restores application files
  and logical databases, restarts services, and runs runtime verification.

## Upstream references

- [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [Docker packet filtering](https://docs.docker.com/engine/network/firewall-iptables/)
- [AlphaVPS terms](https://alphavps.com/terms)
- [Immich Compose installation](https://docs.immich.app/install/docker-compose/)
- [Seerr migration and official image](https://docs.seerr.dev/migration-guide/)
