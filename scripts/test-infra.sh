#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

while IFS= read -r file; do
  bash -n "$file" || failed=1
done < <(find "$ROOT/scripts" -type f -name '*.sh' -print)

if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t scripts < <(find "$ROOT/scripts" -type f -name '*.sh' -print)
  shellcheck -x "${scripts[@]}" || failed=1
else
  echo "WARN: shellcheck is not installed"
fi

if command -v shfmt >/dev/null 2>&1; then
  mapfile -t formatted_scripts < <(find "$ROOT/scripts" -type f -name '*.sh' -print)
  shfmt -d -i 2 -ci -bn "${formatted_scripts[@]}" || failed=1
else
  echo "WARN: shfmt is not installed"
fi

removed_pattern='open''claw|claw''dbot'
if rg -n -i "$removed_pattern" "$ROOT" --glob '!.git/**' --glob '!nohup.out'; then
  echo "Removed agent references remain" >&2
  failed=1
fi

if rg -n '(^|:)(latest|release|stable)(@|$)' "$ROOT" --glob '*.yml' --glob '*.yaml' --glob '*.env' --glob 'Dockerfile*'; then
  echo "Mutable image references remain" >&2
  failed=1
fi

while IFS= read -r compose_file; do
  [[ "$compose_file" == "$ROOT/proxy/docker-compose.yml" ]] && continue
  # gitea intentionally publishes the git SSH port; docker-firewall.sh and UFW
  # open exactly that port and verify.sh allows it as a public listener.
  [[ "$compose_file" == "$ROOT/gitea/docker-compose.yml" ]] && continue
  if rg -n "^\\s+- [\"']?[0-9]+:" "$compose_file"; then
    echo "Non-proxy stack has a wildcard host-port binding: $compose_file" >&2
    failed=1
  fi
done < <(find "$ROOT" -mindepth 2 -maxdepth 2 -name docker-compose.yml -print | sort)

if git -C "$ROOT" ls-files | while IFS= read -r file; do [[ -e "$ROOT/$file" ]] && echo "$file"; done | grep -Eq '(^|/)(\.env|db\.sqlite3|oidc\.key|users_database\.yml|notification\.txt)$'; then
  echo "Tracked runtime secrets remain" >&2
  failed=1
fi

set -a
# shellcheck disable=SC1091
source "$ROOT/config/versions.env"
# shellcheck disable=SC1091
source "$ROOT/tests/fixture.env"
set +a

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
mapfile -t compose_dirs < <(find "$ROOT" -mindepth 2 -maxdepth 2 -name docker-compose.yml -printf '%h\n' | xargs -n1 basename | sort)
mapfile -t catalog_dirs < <(printf '%s\n' "${FULL_STACKS[@]}" | sort)
if [[ "$(printf '%s\n' "${compose_dirs[@]}")" != "$(printf '%s\n' "${catalog_dirs[@]}")" ]]; then
  echo "Service catalog and Compose directories differ" >&2
  diff -u <(printf '%s\n' "${catalog_dirs[@]}") <(printf '%s\n' "${compose_dirs[@]}") || true
  failed=1
fi

# shellcheck disable=SC2016
mapfile -t caddy_subdomains < <(sed -n 's/^\([a-z0-9-]*\)\.{$ROOT_DOMAIN} {$/\1/p' "$ROOT/proxy/Caddyfile" | sort)
mapfile -t catalog_subdomains < <(printf '%s\n' "${PUBLIC_SUBDOMAINS[@]}" | sort)
if [[ "$(printf '%s\n' "${caddy_subdomains[@]}")" != "$(printf '%s\n' "${catalog_subdomains[@]}")" ]]; then
  echo "Public host catalog and Caddy routes differ" >&2
  failed=1
fi

while IFS= read -r compose_file; do
  if ! (cd "$(dirname "$compose_file")" && docker compose config --quiet); then
    echo "Compose render failed: $compose_file" >&2
    failed=1
  fi
done < <(find "$ROOT" -mindepth 2 -maxdepth 2 -name docker-compose.yml -print | sort)

if docker info >/dev/null 2>&1; then
  docker run --rm --network none -e ROOT_DOMAIN -e GITEA_DOMAIN -e ACME_EMAIL -v "$ROOT/proxy/Caddyfile:/etc/caddy/Caddyfile:ro" "$CADDY_IMAGE" caddy validate --config /etc/caddy/Caddyfile || failed=1
else
  echo "WARN: Docker daemon unavailable; Caddy runtime validation skipped"
fi

exit "$failed"
