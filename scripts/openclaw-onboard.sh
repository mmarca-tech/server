#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_UNIT="${OPENCLAW_UNIT:-openclaw-gateway}"
if [[ "$OPENCLAW_UNIT" == *.service ]]; then
  OPENCLAW_UNIT="${OPENCLAW_UNIT%.service}"
fi

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "sudo is required when running as non-root."
  exit 1
fi

as_root() {
  if [[ -n "$SUDO" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

if [[ ! -f /etc/openclaw/openclaw.env ]]; then
  echo "Missing /etc/openclaw/openclaw.env"
  echo "Run ./scripts/install-openclaw-host.sh first."
  exit 1
fi

if ! id -u openclaw >/dev/null 2>&1; then
  echo "Missing system user: openclaw"
  echo "Run ./scripts/install-openclaw-host.sh first."
  exit 1
fi

if ! as_root systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${OPENCLAW_UNIT}.service"; then
  echo "Missing ${OPENCLAW_UNIT}.service"
  echo "Run ./scripts/install-openclaw-host.sh first."
  exit 1
fi

onboard_cmd='set -a; source /etc/openclaw/openclaw.env; set +a; BROWSER=echo openclaw onboard --no-install-daemon'
if [[ "${EUID}" -eq 0 ]]; then
  su -s /bin/bash -c "$onboard_cmd" openclaw
else
  sudo -u openclaw -H bash -lc "$onboard_cmd"
fi
