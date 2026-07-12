# Script Interfaces

- `deploy.sh` — authoritative Debian 12 installation and deployment entrypoint.
- `stack.sh` — up, down, pull, logs, status, backup, and verify operations.
- `verify.sh` — static repository checks plus optional runtime exposure checks.
- `test-infra.sh` — local syntax, secret-tracking, image, and naming checks.
- `backup.sh` — root-only configuration and persistent-data backup.
- `restore.sh` — checksum-verified, explicit restore with logical DB imports.
- `docker-firewall.sh` — persistent Docker ingress policy installed by deploy.
- `torrent-search.sh` — optional lawful-content CLI helper.

All infrastructure commands derive their service list from `lib/common.sh`.
Do not create a second stack array in another script.
