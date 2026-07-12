#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then exec sudo -E "$0" "$@"; fi

backup="${1:-}"
confirmation="${2:-}"
[[ -d "$backup" && -f "$backup/SHA256SUMS" ]] || {
  echo "Usage: $0 BACKUP_DIRECTORY --confirm" >&2
  exit 1
}
[[ "$confirmation" == --confirm ]] || {
  echo "Restore is destructive; pass --confirm." >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_environment

(cd "$backup" && sha256sum -c SHA256SUMS)
"$SCRIPT_DIR/stack.sh" down

cp -a "$backup/etc-server-infra/." /etc/server-infra/
tar --xattrs --acls -C /srv -xzf "$backup/persistent-data.tar.gz"
export DEPLOY_CONFIG=/etc/server-infra/deploy.env
load_environment

compose nextcloud up -d --wait database cache
compose immich up -d --wait database cache
compose openproject up -d --wait database cache
compose nextcloud exec -T -e MYSQL_PWD="$NEXTCLOUD_DB_PASSWORD" database mariadb -unextcloud nextcloud <"$backup/nextcloud.sql"
compose immich exec -T database pg_restore --clean --if-exists -U immich -d immich <"$backup/immich.dump"
compose openproject exec -T database pg_restore --clean --if-exists -U openproject -d openproject <"$backup/openproject.dump"
if [[ "$DEPLOY_PROFILE" == full ]]; then
  compose invidious up -d --wait database
  compose invidious exec -T database pg_restore --clean --if-exists -U invidious -d invidious <"$backup/invidious.dump"
fi

if [[ -d "$backup/sqlite" ]]; then
  while IFS= read -r -d '' sqlite_backup; do
    relative="${sqlite_backup#"$backup/sqlite/"}"
    target="/srv/$relative"
    install -d -m 0750 -o "$PUID" -g "$PGID" "$(dirname "$target")"
    if [[ -e "$target" ]]; then
      owner="$(stat -c '%u' "$target")"
      group="$(stat -c '%g' "$target")"
      mode="$(stat -c '%a' "$target")"
    else
      owner="$PUID"
      group="$PGID"
      mode=0640
    fi
    install -m "$mode" -o "$owner" -g "$group" "$sqlite_backup" "$target"
  done < <(find "$backup/sqlite" -type f -print0)
fi

"$SCRIPT_DIR/stack.sh" up
"$SCRIPT_DIR/verify.sh" --runtime
echo "Restore completed from: $backup"
