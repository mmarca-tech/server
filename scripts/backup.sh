#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then exec sudo -E "$0" "$@"; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_environment

backup_root="${BACKUP_ROOT:-/srv/backups}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
destination="$backup_root/server-infra-$timestamp"
mkdir -p "$destination"
chmod 700 "$backup_root" "$destination"

docker ps --format '{{.Names}}' >"$destination/containers.txt"
cp -a /etc/server-infra "$destination/etc-server-infra"

restart_stack() {
  "$SCRIPT_DIR/stack.sh" up >/dev/null 2>&1 || true
}
trap restart_stack EXIT
"$SCRIPT_DIR/stack.sh" down
compose nextcloud up -d --wait database cache
compose immich up -d --wait database cache

compose nextcloud exec -T -e MYSQL_PWD="$NEXTCLOUD_DB_PASSWORD" database mariadb-dump -unextcloud --single-transaction nextcloud >"$destination/nextcloud.sql"
compose immich exec -T database pg_dump -Fc -U immich immich >"$destination/immich.dump"

while IFS= read -r -d '' database; do
  relative="${database#/srv/}"
  sqlite_backup="$destination/sqlite/$relative"
  mkdir -p "$(dirname "$sqlite_backup")"
  sqlite3 "$database" ".backup '$sqlite_backup'"
done < <(find /srv/audiobookshelf /srv/authelia /srv/bazarr /srv/calibre /srv/jellyfin /srv/lidarr /srv/mollysocket /srv/prowlarr /srv/radarr /srv/seerr /srv/sonarr -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print0)

tar --xattrs --acls -C /srv -czf "$destination/persistent-data.tar.gz" \
  adguard authelia audiobookshelf bazarr calibre gluetun jellyfin lidarr mollysocket nextcloud prowlarr proxy radarr recyclarr seerr sonarr tdarr transmission
sums_file="$(mktemp)"
(
  cd "$destination"
  find . -type f -print0 | sort -z | xargs -0 sha256sum
) >"$sums_file"
install -m 0600 "$sums_file" "$destination/SHA256SUMS"
rm -f "$sums_file"
"$SCRIPT_DIR/stack.sh" up
trap - EXIT
echo "Backup created: $destination"
