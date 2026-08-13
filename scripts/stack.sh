#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_environment

action="${1:-status}"
target="${2:-all}"

if [[ "$action" == restore ]]; then
  exec "$SCRIPT_DIR/restore.sh" "${2:-}" "${3:-}"
fi

mapfile -t stacks < <(selected_stacks)
if [[ "$target" != all ]]; then
  stacks=("$target")
fi

case "$action" in
  up)
    # Containers and their networks can be lost together (an unclean shutdown
    # drops both), so recovering must not require a full deploy run.
    ensure_networks
    for stack in "${stacks[@]}"; do
      echo "Starting $stack"
      # Air-gapped mollysocket has no web server and exits until at least one
      # Signal connection is registered, so it can never satisfy --wait. Start
      # it without gating the deploy on its health; it has no dependents.
      if [[ "$stack" == mollysocket ]]; then
        compose "$stack" up -d --build
      else
        compose "$stack" up -d --build --wait --wait-timeout "${COMPOSE_WAIT_TIMEOUT:-600}"
      fi
    done
    ;;
  down)
    for ((i = ${#stacks[@]} - 1; i >= 0; i--)); do
      echo "Stopping ${stacks[$i]}"
      compose "${stacks[$i]}" down --remove-orphans
    done
    ;;
  pull)
    for stack in "${stacks[@]}"; do
      echo "Pulling $stack"
      compose "$stack" pull --ignore-buildable
    done
    ;;
  logs)
    [[ "$target" != all ]] || die "logs requires a stack name"
    compose "$target" logs --tail "${LOG_TAIL:-200}" "${@:3}"
    ;;
  status)
    docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    ;;
  backup)
    exec "$SCRIPT_DIR/backup.sh"
    ;;
  verify)
    exec "$SCRIPT_DIR/verify.sh" --runtime
    ;;
  *)
    die "Usage: $0 {up|down|pull|logs|status|backup|restore|verify} [stack-or-backup]"
    ;;
esac
