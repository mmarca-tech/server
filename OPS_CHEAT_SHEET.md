# Ops Cheat Sheet

Short version of how to maintain this server without doing something stupid.

## Ground rules

- Work from `/srv/server`.
- Prefer `make` targets over ad-hoc commands.
- Treat `/srv/server` docs as source of truth, but verify reality before changing live services.
- OpenClaw is host-native and should stay local/loopback. Do not expose it through Caddy or public DNS.
- AdGuard is LAN-only. Do not expose it publicly.
- Prowlarr lives behind gluetun. Use `http://gluetun:9696/...`, not `http://prowlarr:9696/...`.

## Normal maintenance flow

```bash
cd /srv/server
make security-check
make pull
make up
```

If something is broken:

```bash
cd /srv/server
make logs stack=<stack>
make logs stack=<stack> service=<service>
```

If a full controlled stop is needed:

```bash
cd /srv/server
make down
```

## What each command is for

### Health and exposure audit

```bash
make security-check
```

Checks for:
- OpenClaw public exposure mistakes
- missing or broad UFW rules
- mutable image tags
- insecure `.env` permissions
- Docker/OpenClaw wiring problems

Run this before and after bigger changes.

### Pull updated images

```bash
make pull
```

Pulls all stack images without restarting them.

### Start/reconcile stacks

```bash
make up
```

Starts stacks in the intended order, creates the `proxy` network if missing, checks shared media dirs, and auto-runs the Nextcloud proxy fix unless disabled.

### Stop all stacks

```bash
make down
```

Stops all stacks and removes orphans. Handles both current and legacy compose project names.

### Logs

```bash
make logs stack=proxy
make logs stack=nextcloud service=nextcloud
make logs stack=immich
```

Use this first when something fails.

## Provisioning / structural changes

Use these for setup or major rebuilds, not routine maintenance:

```bash
make bootstrap
make init
make docker-install
make openclaw-install
make openclaw-onboard
make master-setup
```

Notes:
- `make init` is safe to re-run; it preserves existing `.env` files and only appends missing keys.
- `make docker-install` expects to manage Docker data root at `/srv/docker`.
- `make openclaw-install` installs OpenClaw host-native and wires the `openclaw` service user.

## Fast triage

### 1. Service down or unhealthy

```bash
cd /srv/server
make logs stack=<stack>
docker ps -a
```

Then:
- check container exit reason
- check disk space with `df -h`
- run `make up` if the fix is just reconciliation

### 2. Reverse proxy / HTTPS issue

```bash
cd /srv/server
make logs stack=proxy
```

Check:
- Caddy upstream target
- DNS/port forwarding
- cert errors

### 3. Media automation issue

Remember:
- Sonarr/Radarr/Lidarr must talk to Prowlarr via `gluetun:9696`
- Transmission traffic is behind gluetun/ProtonVPN

### 4. OpenClaw issue

Check:
```bash
openclaw status
openclaw gateway status
journalctl -u openclaw-gateway.service -n 100
```

## Cleanup / reporting

```bash
./scripts/docker-maintenance.sh
./scripts/generate-monitoring-report.sh
```

Use `docker-maintenance.sh` for pruning old Docker junk.
Use `generate-monitoring-report.sh` for a quick daily snapshot.

## After making changes

Commit the docs or infra change:

```bash
cd /srv/server
./scripts/git-auto-commit.sh "Describe the change"
```

Keep commits focused. Don’t batch unrelated fixes.
