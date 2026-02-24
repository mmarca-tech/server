#!/usr/bin/env bash
set -euo pipefail

DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-/srv/docker}"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER:-}}}"

if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  fi
  echo "Run as root (or install sudo and run with sudo)."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Installing Docker prerequisites"
apt update
apt install -y ca-certificates curl gnupg rsync

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "Configuring Docker APT repository"
arch="$(dpkg --print-architecture)"
. /etc/os-release
cat > /etc/apt/sources.list.d/docker.list <<EOL
deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable
EOL

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

mkdir -p "$DOCKER_DATA_ROOT"

has_existing_docker_data="false"
if [[ -d /var/lib/docker ]] && find /var/lib/docker -mindepth 1 -print -quit | grep -q .; then
  has_existing_docker_data="true"
fi

if [[ "$has_existing_docker_data" == "true" ]]; then
  echo "Stopping Docker services before potential migration"
  systemctl stop docker docker.socket containerd || true

  if find "$DOCKER_DATA_ROOT" -mindepth 1 -print -quit | grep -q .; then
    echo "Target Docker data root is not empty: $DOCKER_DATA_ROOT"
    echo "Skipping automatic migration from /var/lib/docker."
  else
    echo "Migrating /var/lib/docker to $DOCKER_DATA_ROOT"
    rsync -aHAX --delete /var/lib/docker/ "$DOCKER_DATA_ROOT/"

    backup_path="/var/lib/docker.bak.$(date +%Y%m%d%H%M%S)"
    mv /var/lib/docker "$backup_path"
    mkdir -p /var/lib/docker
    echo "Old Docker data backed up at: $backup_path"
  fi
else
  echo "No existing Docker data found; using fresh Docker data root."
fi

mkdir -p /etc/docker
if [[ -f /etc/docker/daemon.json ]]; then
  escaped_root="$(printf '%s\n' "$DOCKER_DATA_ROOT" | sed 's/[.[\\*^$()+?{|]/\\&/g')"
  if grep -Eq "\"data-root\"[[:space:]]*:[[:space:]]*\"${escaped_root}\"" /etc/docker/daemon.json; then
    echo "Existing /etc/docker/daemon.json already points to $DOCKER_DATA_ROOT"
  else
    backup_daemon="/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
    cp /etc/docker/daemon.json "$backup_daemon"
    cat > /etc/docker/daemon.json <<EOL
{
  "data-root": "${DOCKER_DATA_ROOT}"
}
EOL
    echo "Replaced /etc/docker/daemon.json (backup: $backup_daemon)"
  fi
else
  cat > /etc/docker/daemon.json <<EOL
{
  "data-root": "${DOCKER_DATA_ROOT}"
}
EOL
fi

systemctl daemon-reload
systemctl enable --now containerd docker

if getent group docker >/dev/null 2>&1; then
  :
else
  groupadd docker
fi

if id "$TARGET_USER" >/dev/null 2>&1; then
  /usr/sbin/usermod -aG docker "$TARGET_USER" || true
  echo "User added to docker group (if not already): $TARGET_USER"
else
  echo "Target user not found, skipping docker group assignment: $TARGET_USER"
fi

echo "Verifying Docker root dir"
docker info | grep -E 'Docker Root Dir|Server Version' || true

echo
echo "Docker installation complete."
echo "Data root configured at: $DOCKER_DATA_ROOT"
echo "If your user was newly added to docker group, log out and log back in."
