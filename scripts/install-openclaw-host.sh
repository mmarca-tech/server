#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NODE_MAJOR="${NODE_MAJOR:-22}"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a regular user with sudo access (not root)."
  exit 1
fi

echo "Installing prerequisites"
sudo apt update
sudo apt install -y ca-certificates curl gnupg

need_node_install="false"
if ! command -v node >/dev/null 2>&1; then
  need_node_install="true"
else
  current_major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
  if (( current_major < NODE_MAJOR )); then
    need_node_install="true"
  fi
fi

if [[ "$need_node_install" == "true" ]]; then
  echo "Installing Node.js ${NODE_MAJOR}.x"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt install -y nodejs
fi

echo "Installing OpenClaw globally"
sudo npm install -g openclaw@latest

if ! id -u openclaw >/dev/null 2>&1; then
  echo "Creating system user: openclaw"
  sudo useradd --system --create-home --home-dir /var/lib/openclaw --shell /usr/sbin/nologin openclaw
fi

sudo mkdir -p /var/lib/openclaw
sudo chown -R openclaw:openclaw /var/lib/openclaw

sudo mkdir -p /etc/openclaw
if [[ ! -f /etc/openclaw/openclaw.env ]]; then
  echo "Creating /etc/openclaw/openclaw.env from template"
  sudo cp "$ROOT_DIR/openclaw/openclaw.env.example" /etc/openclaw/openclaw.env
fi
sudo chown root:openclaw /etc/openclaw/openclaw.env
sudo chmod 640 /etc/openclaw/openclaw.env

sudo install -m 0644 "$ROOT_DIR/openclaw/systemd/openclaw-gateway.service" /etc/systemd/system/openclaw-gateway.service
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw-gateway

echo "OpenClaw gateway service installed and started."
echo "Next: edit /etc/openclaw/openclaw.env and restart with: sudo systemctl restart openclaw-gateway"
