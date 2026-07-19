# Pinned Versions

`config/versions.env` is the machine-readable source of truth. It was resolved
on 2026-07-12 against stable upstream releases and linux/amd64 manifests.

| Component | Pinned release |
|---|---|
| Caddy | 2.11.4 |
| Nextcloud / MariaDB / Redis | 34.0.1 / 11.8.8 / 8.2.7 |
| Immich | 3.0.2 with the official VectorChord 0.4.3 PostgreSQL image |
| Jellyfin | 10.11.11 |
| Seerr | 3.3.0 |
| Calibre-Web | 0.6.26-ls391 image build |
| Audiobookshelf | 2.35.1 |
| Authelia | 4.39.20 |
| AdGuard Home | 0.107.77 |
| MollySocket | 1.7.1 |
| Gluetun / Transmission | 3.41.1 / 4.1.3 application release |
| Sonarr / Radarr | 4.0.19.2979 / 6.2.1.10461 |
| Prowlarr / Lidarr | 2.4.0.5397 / 3.1.0.4875 |
| Bazarr / FlareSolverr | 1.6.0 / 3.5.0 |
| Tdarr / Recyclarr | 2.83.01 / 8.6.0 |
| Woodpecker agent | 3.16.0 |
| Gitea / Act runner | 1.27.0 / 0.6.1 |

Images without stable numbered container tags are referenced by repository plus
immutable digest without a mutable alias. Update all coupled components
together, especially Immich/server/ML/database. Review release notes and
replace both tag and digest in the same change.
