#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/docker-ghost-cleanup.sh [--apply] [--prune] [id ...]

Description:
  Detects "ghost" container IDs that appear in `docker ps -a` but fail `docker inspect`.
  By default this runs in dry-run mode and prints what would be removed.

Options:
  --apply   Execute cleanup (requires root; run with sudo).
  --prune   Run `docker system prune -a --volumes -f` after cleanup (only with --apply).
  -h, --help  Show this help.

Examples:
  ./scripts/docker-ghost-cleanup.sh
  sudo ./scripts/docker-ghost-cleanup.sh --apply
  sudo ./scripts/docker-ghost-cleanup.sh --apply --prune
  sudo ./scripts/docker-ghost-cleanup.sh --apply <container-id> <container-id>
EOF
}

log() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

apply=false
prune=false
declare -a requested_ids=()

while (($# > 0)); do
  case "$1" in
    --apply)
      apply=true
      ;;
    --prune)
      prune=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while (($# > 0)); do
        requested_ids+=("$1")
        shift
      done
      break
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      requested_ids+=("$1")
      ;;
  esac
  shift
done

if [[ "$prune" == true && "$apply" != true ]]; then
  fail "--prune requires --apply."
fi

if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI not found."
fi

if ! command -v systemctl >/dev/null 2>&1; then
  fail "systemctl not found. This script currently supports systemd hosts."
fi

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not reachable. Start Docker and retry."
fi

docker_root_dir="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
if [[ -z "$docker_root_dir" ]]; then
  fail "Could not detect DockerRootDir."
fi

declare -A seen_ids=()
declare -a candidate_ids=()

if (( ${#requested_ids[@]} > 0 )); then
  for id in "${requested_ids[@]}"; do
    if [[ -z "${seen_ids[$id]:-}" ]]; then
      seen_ids["$id"]=1
      candidate_ids+=("$id")
    fi
  done
else
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if [[ -z "${seen_ids[$id]:-}" ]]; then
      seen_ids["$id"]=1
      candidate_ids+=("$id")
    fi
  done < <(docker ps -aq --no-trunc --filter status=exited)
fi

if (( ${#candidate_ids[@]} == 0 )); then
  log "No exited containers found to evaluate."
  exit 0
fi

declare -a inspectable_ids=()
declare -a ghost_ids=()
declare -a invalid_ids=()

for id in "${candidate_ids[@]}"; do
  if [[ ! "$id" =~ ^[0-9a-f]{12,64}$ ]]; then
    invalid_ids+=("$id")
    continue
  fi

  if docker inspect "$id" >/dev/null 2>&1; then
    inspectable_ids+=("$id")
  else
    ghost_ids+=("$id")
  fi
done

log "Docker root dir: $docker_root_dir"
log "Candidates checked: ${#candidate_ids[@]}"
log "Inspectable: ${#inspectable_ids[@]}"
log "Ghost IDs: ${#ghost_ids[@]}"

if (( ${#invalid_ids[@]} > 0 )); then
  warn "Ignoring invalid IDs: ${invalid_ids[*]}"
fi

if (( ${#ghost_ids[@]} == 0 )); then
  log "No ghost container metadata detected."
  exit 0
fi

echo "Ghost metadata paths targeted for removal:"
for id in "${ghost_ids[@]}"; do
  echo "  - $docker_root_dir/containers/$id"
done

if [[ "$apply" != true ]]; then
  log "Dry-run only. Re-run with: sudo ./scripts/docker-ghost-cleanup.sh --apply"
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  fail "--apply requires root. Run this script with sudo."
fi

log "Stopping docker.socket and docker.service"
systemctl stop docker.socket docker.service

removed_paths=0
missing_paths=0
for id in "${ghost_ids[@]}"; do
  container_path="$docker_root_dir/containers/$id"
  if [[ -e "$container_path" ]]; then
    rm -rf "$container_path"
    removed_paths=$((removed_paths + 1))
  else
    missing_paths=$((missing_paths + 1))
  fi
done
log "Removed $removed_paths ghost metadata path(s), $missing_paths already missing."

if command -v ctr >/dev/null 2>&1; then
  for sock in /run/docker/containerd/containerd.sock /run/containerd/containerd.sock; do
    [[ -S "$sock" ]] || continue
    log "Cleaning containerd moby namespace via $sock"
    for id in "${ghost_ids[@]}"; do
      ctr --address "$sock" -n moby tasks rm -f "$id" >/dev/null 2>&1 || true
      ctr --address "$sock" -n moby containers rm "$id" >/dev/null 2>&1 || true
    done
  done
else
  warn "ctr not found; containerd metadata cleanup skipped."
fi

log "Starting docker.service and docker.socket"
systemctl start docker.service docker.socket

if ! docker info >/dev/null 2>&1; then
  fail "Docker did not come back cleanly after restart."
fi

declare -A remaining_map=()
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  remaining_map["$id"]=1
done < <(docker ps -aq --no-trunc)

declare -a still_present=()
for id in "${ghost_ids[@]}"; do
  if [[ -n "${remaining_map[$id]:-}" ]]; then
    still_present+=("$id")
  fi
done

if (( ${#still_present[@]} > 0 )); then
  warn "Some ghost IDs are still listed: ${still_present[*]}"
  warn "Retry with explicit IDs, then inspect containerd state manually if needed."
else
  log "Ghost IDs are no longer listed by docker ps -a."
fi

if [[ "$prune" == true ]]; then
  log "Running docker system prune -a --volumes -f"
  docker system prune -a --volumes -f
fi

log "Done."
