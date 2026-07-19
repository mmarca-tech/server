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

No public application publishes its backend port to the host. Caddy reaches it
through the external `proxy` Docker network.

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

The Woodpecker CI agent has no inbound exposure either: it opens an outbound
gRPC/TLS connection to Codeberg's hosted server (`grpc.ci.codeberg.org:443`) and
waits for pipeline work. It uses the Docker backend, so it mounts the host
Docker socket and runs pipeline steps as sibling containers on the host daemon
— effectively root-equivalent host access, the standard tradeoff for a
self-hosted CI runner. Its agent ID persists in `/srv/woodpecker`.
