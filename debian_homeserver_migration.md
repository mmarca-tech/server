# Debian Home Server Migration (Archived)

This file is kept for historical context.

The active and correct infrastructure documentation is:

- `SETUP_GUIDE.md` (authoritative setup guide)
- `README.md` (quick start and operations)

## Current Pathing Baseline

- App data and volumes: `/srv/*`
- Docker root: `/srv/docker` (recommended for this host layout)
- OpenClaw host config: `/etc/openclaw/openclaw.env`

Current `/srv` tree used by this repository:

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

Do not use legacy `/srv/data` or `/srv/compose` examples from older revisions.
