# Services and Access

## Public through Caddy

| Service | Address | Persistent data |
|---|---|---|
| Nextcloud | `https://nc.DOMAIN` | `/srv/nextcloud`, `/srv/databases/nextcloud-mariadb` |
| Immich | `https://immich.DOMAIN` | `/srv/media/immich`, `/srv/databases/immich-postgres` |
| Jellyfin | `https://hometheater.DOMAIN` | `/srv/jellyfin`, `/srv/media` |
| Seerr | `https://seerr.DOMAIN` | `/srv/seerr` |
| Calibre-Web | `https://calibre.DOMAIN` | `/srv/calibre`, `/srv/media/books` |
| Audiobookshelf | `https://audiobookshelf.DOMAIN` | `/srv/audiobookshelf`, `/srv/media` |
| Authelia | `https://auth.DOMAIN` | `/srv/authelia` |
| Gitea | `https://GITEA_DOMAIN` (its own domain) | `/srv/gitea` |

Most public applications publish no backend port to the host; Caddy reaches
them through the external `proxy` Docker network. The one exception is Gitea's
git-over-SSH port (`GITEA_SSH_PORT`, default 2222) — the only non-Caddy public
port — opened explicitly in UFW and the Docker ingress policy. Gitea's HTTP
still flows through Caddy like every other app.

Gitea is served on its own domain (`GITEA_DOMAIN`, e.g. `git.mmarca.tech`)
rather than a `ROOT_DOMAIN` subdomain, so it needs a separate A record and gets
its own certificate. Clone over `https://GITEA_DOMAIN/…` or
`ssh://git@GITEA_DOMAIN:GITEA_SSH_PORT/…`. The admin user (matching
`ADMIN_USER`) and its password are created on first deploy; the password is in
`/etc/server-infra/secrets.env`.

## WireGuard-only administration

Default WireGuard server address is `10.66.0.1`.

| Service | Private address |
|---|---|
| AdGuard setup/DNS | `http://10.66.0.1:3001`, TCP/UDP 53 |
| Transmission | `http://10.66.0.1:9091` |
| Prowlarr | `http://10.66.0.1:9696` |
| Sonarr | `http://10.66.0.1:8989` |
| Radarr | `http://10.66.0.1:7878` |
| Lidarr | `http://10.66.0.1:8686` |
| Bazarr | `http://10.66.0.1:6767` |
| Tdarr | `http://10.66.0.1:8265` |

AdGuard's host-side admin port defaults to 3001. The container still receives
AdGuard traffic on port 3000.

Gluetun, Transmission, and Prowlarr share one Compose project and network
namespace. Sonarr/Radarr/Lidarr reach Prowlarr at `http://gluetun:9696` and
Transmission at `http://gluetun:9091` on `home-network`. FlareSolverr is
internal at `http://flaresolverr:8191`.

## Internal-only services

Application databases, Redis/Valkey, Immich machine learning, FlareSolverr,
Recyclarr, and MollySocket have no public host binding. MollySocket remains
air-gapped unless intentionally redesigned.

The Gitea Actions runner (act_runner) is internal-only: it registers to Gitea
over the internal Docker network and, like any CI runner, mounts the host Docker
socket to run pipeline steps as sibling containers — root-equivalent host
access. Its registration token is generated at deploy time into
`/etc/server-infra/secrets.env`, and its identity persists in
`/srv/gitea/act-runner`.

The Woodpecker CI agent has no inbound exposure either: it opens an outbound
gRPC/TLS connection to Codeberg's hosted server (`ci.codeberg.org:443`) and
waits for pipeline work. It uses the Docker backend, so it mounts the host
Docker socket and runs pipeline steps as sibling containers on the host daemon
— effectively root-equivalent host access, the standard tradeoff for a
self-hosted CI runner. Its agent ID persists in `/srv/woodpecker`.
