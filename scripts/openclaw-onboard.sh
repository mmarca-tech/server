#!/usr/bin/env bash
set -euo pipefail

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

sudo -u openclaw -H bash -lc 'set -a; source /etc/openclaw/openclaw.env; set +a; BROWSER=echo openclaw onboard --no-install-daemon'
