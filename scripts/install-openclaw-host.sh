#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NODE_MAJOR="${NODE_MAJOR:-22}"
OPENCLAW_UNIT="${OPENCLAW_UNIT:-openclaw-gateway}"
if [[ "$OPENCLAW_UNIT" == *.service ]]; then
  OPENCLAW_UNIT="${OPENCLAW_UNIT%.service}"
fi

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
  sudo useradd --system --create-home --home-dir /srv/openclaw --shell /usr/sbin/nologin openclaw
else
  # Ensure existing installs use /srv/openclaw as home to avoid filling /var.
  sudo /usr/sbin/usermod -d /srv/openclaw openclaw || true
fi

echo "Ensuring Docker access for openclaw service user"
if ! getent group docker >/dev/null 2>&1; then
  sudo groupadd docker
fi
if ! id -nG openclaw | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker openclaw
fi

echo "Granting openclaw sudo access for package upgrades"
sudoers_file="/etc/sudoers.d/openclaw"
desired_sudoers="openclaw ALL=(ALL) NOPASSWD: /usr/bin/apt update, /usr/bin/apt upgrade -y, /usr/bin/apt full-upgrade -y, /usr/bin/crontab"
current_sudoers="$(sudo cat "$sudoers_file" 2>/dev/null || true)"
if [[ "$current_sudoers" != "$desired_sudoers" ]]; then
  echo "$desired_sudoers" | sudo tee "$sudoers_file" >/dev/null
  sudo chmod 440 "$sudoers_file"
  sudo visudo -c -f "$sudoers_file"
fi

echo "Setting up openclaw log directory"
sudo mkdir -p /var/log/openclaw
sudo chown openclaw:openclaw /var/log/openclaw

echo "Registering daily package update cron job"
sudo -u openclaw openclaw cron add \
  --name "daily-package-update" \
  --schedule "0 2 * * *" \
  --command "sudo apt update && sudo apt upgrade -y" \
  --log /var/log/openclaw/package-update.log \
  --notify-on-success \
  --notify-on-failure \
  2>/dev/null || echo "Cron job 'daily-package-update' already registered, skipping."

if [[ -d /var/lib/openclaw ]] && [[ ! -L /var/lib/openclaw ]]; then
  echo "Migrating existing OpenClaw data from /var/lib/openclaw to /srv/openclaw"
  sudo mkdir -p /srv/openclaw
  sudo rsync -aHAX --delete /var/lib/openclaw/ /srv/openclaw/ || true
fi

sudo mkdir -p /srv/openclaw
sudo chown -R openclaw:openclaw /srv/openclaw

sudo mkdir -p /etc/openclaw
if [[ ! -f /etc/openclaw/openclaw.env ]]; then
  echo "Creating /etc/openclaw/openclaw.env from template"
  sudo cp "$ROOT_DIR/openclaw/openclaw.env.example" /etc/openclaw/openclaw.env
fi
sudo chown root:openclaw /etc/openclaw/openclaw.env
sudo chmod 640 /etc/openclaw/openclaw.env

sudo install -m 0644 "$ROOT_DIR/openclaw/systemd/openclaw-gateway.service" "/etc/systemd/system/${OPENCLAW_UNIT}.service"
sudo systemctl daemon-reload
sudo systemctl enable --now "${OPENCLAW_UNIT}.service"

if ! sudo systemctl is-active --quiet "${OPENCLAW_UNIT}.service"; then
  echo "OpenClaw service failed to start. Recent logs:"
  sudo journalctl -u "${OPENCLAW_UNIT}.service" -n 80 --no-pager || true
  exit 1
fi

echo "OpenClaw service identity:"
sudo systemctl show "${OPENCLAW_UNIT}.service" -p User -p SupplementaryGroups

echo "OpenClaw gateway service installed and started."
echo "Next: edit /etc/openclaw/openclaw.env and restart with: sudo systemctl restart ${OPENCLAW_UNIT}.service"
