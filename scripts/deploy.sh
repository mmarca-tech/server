#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEPLOY_CONFIG="${DEPLOY_CONFIG:-/root/server.env}"
export SECRETS_FILE="${SECRETS_FILE:-/etc/server-infra/secrets.env}"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

mode=deploy
case "${1:-}" in
  --check) mode=check ;;
  --resume) mode=resume ;;
  "") ;;
  *) die "Usage: sudo DEPLOY_CONFIG=/root/server.env $0 [--check|--resume]" ;;
esac

require_root
load_environment

required=(ROOT_DOMAIN ACME_EMAIL TZ ADMIN_USER ADMIN_EMAIL SSH_PUBLIC_KEY PUBLIC_IPV4 WG_ADDRESS WG_CLIENT_ADDRESS WG_PORT WG_CLIENT_NAME)

is_true() { [[ "${1:-false}" == true ]]; }
is_placeholder() { [[ -z "$1" || "$1" == *REPLACE* || "$1" == example.com || "$1" == 203.0.113.* ]]; }

preflight() {
  local key value mode_bits cpus memory_kb
  SSH_PORT="${SSH_PORT:-22}"
  ADGUARD_ADMIN_PORT="${ADGUARD_ADMIN_PORT:-3001}"
  export SSH_PORT ADGUARD_ADMIN_PORT
  for key in "${required[@]}"; do
    value="${!key:-}"
    is_placeholder "$value" && die "$key is missing or still a placeholder"
  done
  [[ "$SSH_PUBLIC_KEY" == ssh-*' '* ]] || die "SSH_PUBLIC_KEY is not a supported public key"
  is_placeholder "${AUTHELIA_ADMIN_PASSWORD_HASH:-}" && die "Set AUTHELIA_ADMIN_PASSWORD_HASH"
  # shellcheck disable=SC2016
  [[ "$AUTHELIA_ADMIN_PASSWORD_HASH" == '$argon2id$'* ]] || die "AUTHELIA_ADMIN_PASSWORD_HASH must be an Argon2id hash"
  is_placeholder "${WOODPECKER_AGENT_SECRET:-}" && die "Set WOODPECKER_AGENT_SECRET (Codeberg CI agent secret)"
  [[ "$ROOT_DOMAIN" =~ ^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$ ]] || die "ROOT_DOMAIN is invalid"
  [[ "$ACME_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "ACME_EMAIL is invalid"
  [[ "$ADMIN_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "ADMIN_EMAIL is invalid"
  [[ -e "/usr/share/zoneinfo/$TZ" ]] || die "TZ is not an installed IANA timezone"
  [[ "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "ADMIN_USER is not a valid Linux username"
  [[ "$WG_CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || die "WG_CLIENT_NAME contains unsafe characters"
  if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || ((SSH_PORT < 1 || SSH_PORT > 65535)); then die "SSH_PORT is invalid"; fi
  if [[ ! "$WG_PORT" =~ ^[0-9]+$ ]] || ((WG_PORT < 1 || WG_PORT > 65535)); then die "WG_PORT is invalid"; fi
  if [[ ! "$ADGUARD_ADMIN_PORT" =~ ^[0-9]+$ ]] || ((ADGUARD_ADMIN_PORT < 1 || ADGUARD_ADMIN_PORT > 65535)); then die "ADGUARD_ADMIN_PORT is invalid"; fi
  [[ "$SSH_PORT" != 80 && "$SSH_PORT" != 443 ]] || die "SSH_PORT conflicts with Caddy"
  [[ "$WG_PORT" != 53 && "$WG_PORT" != 443 ]] || die "WG_PORT conflicts with another UDP listener"
  case "$ADGUARD_ADMIN_PORT" in
    53 | 3000 | 6767 | 7878 | 8123 | 8265 | 8266 | 8686 | 8989 | 9091 | 9696)
      die "ADGUARD_ADMIN_PORT conflicts with a private service"
      ;;
  esac
  mode_bits="$(stat -c '%a' "$DEPLOY_CONFIG")"
  ((10#$mode_bits <= 600)) || die "$DEPLOY_CONFIG must have mode 600 or stricter"
  [[ "$(stat -c '%u' "$DEPLOY_CONFIG")" == 0 ]] || die "$DEPLOY_CONFIG must be owned by root"
  [[ "$(uname -m)" == x86_64 ]] || die "Only x86_64 is supported"
  if ! is_true "${ALLOW_UNSUPPORTED_OS:-false}"; then
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "$ID" == debian && "$VERSION_ID" == 12 ]] || die "This deployment supports Debian 12 only"
  fi
  # shellcheck disable=SC2153
  ip -4 address show | grep -Fq "$PUBLIC_IPV4" || die "PUBLIC_IPV4 is not configured on this host"
  if [[ -n "${PUBLIC_IPV6:-}" ]]; then
    ip -6 address show | grep -Fq "$PUBLIC_IPV6" || die "PUBLIC_IPV6 is not configured on this host"
  fi
  [[ "$DEPLOY_PROFILE" == core || "$DEPLOY_PROFILE" == full ]] || die "DEPLOY_PROFILE must be core or full"
  if [[ "$DEPLOY_PROFILE" == full ]]; then
    [[ -c /dev/net/tun ]] || die "/dev/net/tun is unavailable on this VPS"
    is_true "${DEDICATED_CPU_ACK:-false}" || die "Set DEDICATED_CPU_ACK=true for the full profile"
    is_true "${LAWFUL_MEDIA_ACK:-false}" || die "Set LAWFUL_MEDIA_ACK=true for the full profile"
    is_placeholder "${PROTON_WIREGUARD_PRIVATE_KEY:-}" && die "Set fresh Proton WireGuard credentials"
    is_placeholder "${PROTON_WIREGUARD_ADDRESSES:-}" && die "Set PROTON_WIREGUARD_ADDRESSES"
    cpus="$(nproc)"
    memory_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
    if ! is_true "${ALLOW_LOW_RESOURCES:-false}"; then
      ((cpus >= 8)) || die "Full profile requires at least 8 vCPUs or ALLOW_LOW_RESOURCES=true"
      ((memory_kb >= 15000000)) || die "Full profile requires about 16 GB RAM or ALLOW_LOW_RESOURCES=true"
      available_gb="$(df -Pk / | awk 'NR==2 {print int($4/1024/1024)}')"
      ((available_gb >= 40)) || die "Full profile requires at least 40 GB free or ALLOW_LOW_RESOURCES=true"
    fi
  fi
  if ! is_true "${SKIP_DNS_CHECK:-false}"; then
    local host resolved resolved6
    while IFS= read -r host; do
      resolved="$(getent ahostsv4 "$host" | awk 'NR==1 {print $1}' || true)"
      # shellcheck disable=SC2153
      [[ "$resolved" == "$PUBLIC_IPV4" ]] || die "$host does not resolve to PUBLIC_IPV4"
      # getent ahostsv6 returns IPv4-mapped addresses (::ffff:a.b.c.d) for
      # A-only hosts; skip those so we only detect real AAAA records.
      resolved6="$(getent ahostsv6 "$host" | awk '$1 !~ /^::ffff:/ {print $1; exit}' || true)"
      if [[ -n "${PUBLIC_IPV6:-}" ]]; then
        [[ "$resolved6" == "$PUBLIC_IPV6" ]] || die "$host does not resolve to PUBLIC_IPV6"
      else
        [[ -z "$resolved6" ]] || die "$host has AAAA DNS but PUBLIC_IPV6 is empty"
      fi
    done < <(public_hosts)
  fi
  if command -v ss >/dev/null 2>&1 && [[ ! -f /var/lib/server-infra/deploy.state ]]; then
    for port in "${SSH_PORT:-22}" 80 443 "${WG_PORT}"; do
      if ss -lntupH | awk '{print $5}' | grep -Eq ":${port}$"; then
        [[ "$port" == "${SSH_PORT:-22}" ]] || die "Required port is already in use: $port"
      fi
    done
  fi
  echo "Preflight passed for Debian 12 / profile $DEPLOY_PROFILE."
}

install_base() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get -y upgrade
  apt-get install -y ca-certificates curl gnupg openssl jq rsync git sudo ripgrep shellcheck shfmt sqlite3 python3 transmission-cli iproute2 openssh-server ufw fail2ban unattended-upgrades wireguard-tools iptables
  dpkg-reconfigure -f noninteractive unattended-upgrades
}

install_docker() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get remove -y docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null || true
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  local arch codename
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  local sources
  sources="$(mktemp)"
  printf 'Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$codename" "$arch" >"$sources"
  install -m 0644 "$sources" /etc/apt/sources.list.d/docker.sources
  rm -f "$sources"
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  install -d -m 0755 /srv/docker /etc/docker
  local daemon
  daemon="$(mktemp)"
  printf '%s\n' '{' '  "data-root": "/srv/docker",' '  "log-driver": "local",' '  "log-opts": {"max-size": "20m", "max-file": "5"},' '  "live-restore": true' '}' >"$daemon"
  install -m 0644 "$daemon" /etc/docker/daemon.json
  rm -f "$daemon"
  systemctl enable --now containerd docker
  docker info >/dev/null
}

install_admin() {
  if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$ADMIN_USER"
  fi
  usermod -aG sudo,docker "$ADMIN_USER"
  local sudoers
  sudoers="$(mktemp)"
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$ADMIN_USER" >"$sudoers"
  install -m 0440 "$sudoers" "/etc/sudoers.d/90-server-infra-$ADMIN_USER"
  rm -f "$sudoers"
  visudo -cf "/etc/sudoers.d/90-server-infra-$ADMIN_USER"
  install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
  local authorized_keys
  authorized_keys="$(mktemp)"
  printf '%s\n' "$SSH_PUBLIC_KEY" >"$authorized_keys"
  install -m 0600 -o "$ADMIN_USER" -g "$ADMIN_USER" "$authorized_keys" "/home/$ADMIN_USER/.ssh/authorized_keys"
  rm -f "$authorized_keys"
  local ssh_config
  ssh_config="$(mktemp)"
  printf 'Port %s\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\nPubkeyAuthentication yes\n' "${SSH_PORT:-22}" >"$ssh_config"
  install -m 0644 "$ssh_config" /etc/ssh/sshd_config.d/60-server-infra.conf
  rm -f "$ssh_config"
  sshd -t
  systemctl reload ssh
  systemctl enable --now fail2ban
}

install_wireguard() {
  install -d -m 0700 /etc/server-infra /etc/wireguard
  umask 077
  if [[ ! -f /etc/server-infra/wg-server.key ]]; then
    wg genkey >/etc/server-infra/wg-server.key
    wg pubkey </etc/server-infra/wg-server.key >/etc/server-infra/wg-server.pub
    wg genkey >/etc/server-infra/wg-client.key
    wg pubkey </etc/server-infra/wg-client.key >/etc/server-infra/wg-client.pub
  fi
  local server_private server_public client_private client_public config
  server_private="$(</etc/server-infra/wg-server.key)"
  server_public="$(</etc/server-infra/wg-server.pub)"
  client_private="$(</etc/server-infra/wg-client.key)"
  client_public="$(</etc/server-infra/wg-client.pub)"
  config="$(mktemp)"
  printf '[Interface]\nAddress = %s\nListenPort = %s\nPrivateKey = %s\n\n[Peer]\nPublicKey = %s\nAllowedIPs = %s\n' "$WG_ADDRESS" "$WG_PORT" "$server_private" "$client_public" "$WG_CLIENT_ADDRESS" >"$config"
  install -m 0600 "$config" /etc/wireguard/wg0.conf
  printf '[Interface]\nAddress = %s\nPrivateKey = %s\n\n[Peer]\nPublicKey = %s\nEndpoint = %s:%s\nAllowedIPs = %s\nPersistentKeepalive = 25\n' "$WG_CLIENT_ADDRESS" "$client_private" "$server_public" "$PUBLIC_IPV4" "$WG_PORT" "$WG_ADDRESS" >"$config"
  install -m 0600 "$config" "/etc/server-infra/wireguard-$WG_CLIENT_NAME.conf"
  rm -f "$config"
  wg-quick strip wg0 >/dev/null
  systemctl enable --now wg-quick@wg0
}

install_firewall() {
  sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT:-22}/tcp" comment 'key-only SSH'
  ufw allow 80/tcp comment 'HTTP ACME and redirect'
  ufw allow 443/tcp comment 'HTTPS'
  ufw allow 443/udp comment 'HTTP3'
  ufw allow "${WG_PORT}/udp" comment 'private administration'
  ufw --force enable
  install -m 0755 "$SCRIPT_DIR/docker-firewall.sh" /usr/local/sbin/server-infra-docker-firewall
  install -m 0644 "$REPO_ROOT/systemd/server-infra-docker-firewall.service" /etc/systemd/system/server-infra-docker-firewall.service
  systemctl daemon-reload
  systemctl enable server-infra-docker-firewall.service
  systemctl restart server-infra-docker-firewall.service
}

prepare_runtime() {
  install -d -m 0700 /etc/server-infra
  install -m 0600 "$DEPLOY_CONFIG" /etc/server-infra/deploy.env
  export DEPLOY_CONFIG=/etc/server-infra/deploy.env
  if ! grep -q '^PUID=' "$DEPLOY_CONFIG"; then
    printf 'PUID=%s\nPGID=%s\n' "$(id -u "$ADMIN_USER")" "$(id -g "$ADMIN_USER")" >>"$DEPLOY_CONFIG"
  fi
  if [[ ! -f "$SECRETS_FILE" ]]; then
    install -m 0600 /dev/null "$SECRETS_FILE"
  fi
  ensure_secret() {
    local key="$1" bytes="${2:-32}"
    grep -q "^${key}=" "$SECRETS_FILE" || printf '%s=%s\n' "$key" "$(openssl rand -hex "$bytes")" >>"$SECRETS_FILE"
  }
  local key
  for key in NEXTCLOUD_DB_ROOT_PASSWORD NEXTCLOUD_DB_PASSWORD NEXTCLOUD_ADMIN_PASSWORD IMMICH_DB_PASSWORD AUTHELIA_SESSION_SECRET AUTHELIA_STORAGE_ENCRYPTION_KEY AUTHELIA_JWT_SECRET; do
    ensure_secret "$key"
  done
  chmod 600 "$SECRETS_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$SECRETS_FILE"
  set +a

  install -d -m 0750 /etc/server-infra/authelia
  chown root:"$ADMIN_USER" /etc/server-infra/authelia
  sed -e "s/__ROOT_DOMAIN__/$ROOT_DOMAIN/g" "$REPO_ROOT/authelia/configuration.yml.template" >/etc/server-infra/authelia/configuration.yml
  chown root:"$ADMIN_USER" /etc/server-infra/authelia/configuration.yml
  chmod 640 /etc/server-infra/authelia/configuration.yml
  install -d -m 0750 -o "$ADMIN_USER" -g "$ADMIN_USER" /srv/authelia
  if [[ ! -f /srv/authelia/users_database.yml ]]; then
    local users_database
    users_database="$(mktemp)"
    {
      printf 'users:\n  %s:\n' "$ADMIN_USER"
      printf '    displayname: "%s"\n' "$ADMIN_USER"
      printf '    password: "%s"\n' "$AUTHELIA_ADMIN_PASSWORD_HASH"
      printf '    email: "%s"\n' "$ADMIN_EMAIL"
      printf '    groups: [admins]\n'
    } >"$users_database"
    install -m 0660 -o "$ADMIN_USER" -g "$ADMIN_USER" "$users_database" /srv/authelia/users_database.yml
    rm -f "$users_database"
  fi

  local dirs=(proxy/caddy-data proxy/caddy-config media media/movies media/tv media/music media/audiobooks media/podcasts media/books media/downloads media/downloads/incomplete media/immich/library nextcloud/html nextcloud/data immich/model-cache jellyfin/config jellyfin/cache seerr/config calibre/config audiobookshelf/config audiobookshelf/metadata authelia adguard/work adguard/conf mollysocket/data transmission/config gluetun prowlarr/config sonarr/config radarr/config lidarr/config bazarr/config tdarr/server tdarr/configs tdarr/logs tdarr/transcode_cache recyclarr/config recyclarr/data woodpecker databases/nextcloud-mariadb databases/immich-postgres backups)
  local dir
  # Only create missing directories. Re-running install -d on an existing
  # directory rewrites its owner and mode, which clobbers data dirs owned by a
  # container's own user (e.g. the Postgres/MariaDB UID) and breaks a running
  # database mid-flight with "Permission denied" on its data files.
  for dir in "${dirs[@]}"; do
    [[ -d "/srv/$dir" ]] || install -d -m 0750 -o "$ADMIN_USER" -g "$ADMIN_USER" "/srv/$dir"
  done
  docker network inspect proxy >/dev/null 2>&1 || docker network create proxy >/dev/null
  docker network inspect home-network >/dev/null 2>&1 || docker network create home-network >/dev/null
}

validate_configs() {
  export DEPLOY_CONFIG=/etc/server-infra/deploy.env
  load_environment
  local stack
  while IFS= read -r stack; do
    compose "$stack" config --quiet
  done < <(selected_stacks)
  docker run --rm --network none -e ROOT_DOMAIN -e ACME_EMAIL -v "$REPO_ROOT/proxy/Caddyfile:/etc/caddy/Caddyfile:ro" "$CADDY_IMAGE" caddy validate --config /etc/caddy/Caddyfile
}

configure_mollysocket() {
  [[ "$DEPLOY_PROFILE" == full ]] || return 0
  if ! grep -q '^MOLLY_VAPID_PRIVKEY=' "$SECRETS_FILE"; then
    local vapid_key
    vapid_key="$(docker run --rm "$MOLLYSOCKET_IMAGE" vapid generate | tail -n 1)"
    [[ "$vapid_key" =~ ^[A-Za-z0-9_-]{40,}$ ]] || die "MollySocket VAPID generation failed"
    printf 'MOLLY_VAPID_PRIVKEY=%s\n' "$vapid_key" >>"$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
  fi
}

deploy_stacks() {
  export DEPLOY_CONFIG=/etc/server-infra/deploy.env
  "$SCRIPT_DIR/stack.sh" up
}

install_monitoring() {
  install -d -m 0755 /var/log/server-infra
  sed "s|/srv/server|$REPO_ROOT|g" "$REPO_ROOT/systemd/server-infra-health.service" >/etc/systemd/system/server-infra-health.service
  chmod 0644 /etc/systemd/system/server-infra-health.service
  install -m 0644 "$REPO_ROOT/systemd/server-infra-health.timer" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now server-infra-health.timer
}

state_file=/var/lib/server-infra/deploy.state
run_stage() {
  local name="$1"
  shift
  if [[ -f "$state_file" ]] && grep -qx "$name" "$state_file"; then
    if [[ "$name" == base-packages || "$name" == docker || "$name" == images ]] || { [[ "$mode" == resume ]] && [[ "$name" == administrator || "$name" == wireguard || "$name" == firewall ]]; }; then
      echo "[SKIP] $name"
      return
    fi
  fi
  echo "[RUN] $name"
  "$@"
  install -d -m 0755 "$(dirname "$state_file")"
  grep -qx "$name" "$state_file" 2>/dev/null || printf '%s\n' "$name" >>"$state_file"
}

preflight
[[ "$mode" == check ]] && exit 0

run_stage base-packages install_base
run_stage docker install_docker
run_stage administrator install_admin
run_stage wireguard install_wireguard
run_stage firewall install_firewall
run_stage runtime prepare_runtime
run_stage molly-secret configure_mollysocket
run_stage images "$SCRIPT_DIR/stack.sh" pull
run_stage validate validate_configs
run_stage services deploy_stacks
run_stage monitoring install_monitoring
run_stage verify "$SCRIPT_DIR/verify.sh" --runtime

echo
echo "Deployment complete. Retrieve /etc/server-infra/wireguard-$WG_CLIENT_NAME.conf securely."
echo "Generated application passwords are stored in $SECRETS_FILE (root-only)."
