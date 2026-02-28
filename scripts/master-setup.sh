#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LAN_IP="${LAN_IP:-192.168.1.20}"
LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"
ROOT_DOMAIN="${ROOT_DOMAIN:-example.com}"
ACME_EMAIL="${ACME_EMAIL:-admin@example.com}"
OPENCLAW_BACKEND="${OPENCLAW_BACKEND:-openai}"
OPENCLAW_MODEL="${OPENCLAW_MODEL:-}"
EXPOSE_HOMEASSISTANT="${EXPOSE_HOMEASSISTANT:-false}"

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "sudo is required when running as non-root."
  exit 1
fi

if [[ "${OPENCLAW_BACKEND}" != "openai" && "${OPENCLAW_BACKEND}" != "anthropic" && "${OPENCLAW_BACKEND}" != "local" && "${OPENCLAW_BACKEND}" != "skip" ]]; then
  echo "Invalid OPENCLAW_BACKEND=${OPENCLAW_BACKEND}"
  echo "Valid values: openai, anthropic, local, skip"
  exit 1
fi

if [[ "${EXPOSE_HOMEASSISTANT}" != "true" && "${EXPOSE_HOMEASSISTANT}" != "false" ]]; then
  echo "Invalid EXPOSE_HOMEASSISTANT=${EXPOSE_HOMEASSISTANT}"
  echo "Valid values: true, false"
  exit 1
fi

manual_checkpoint() {
  local title="$1"
  shift
  echo
  echo "[MANUAL] ${title}"
  for line in "$@"; do
    echo " - ${line}"
  done
  while true; do
    read -r -p "Type 'done' to continue or 'abort' to stop: " ans
    case "$ans" in
      done|DONE|Done)
        break
        ;;
      abort|ABORT|Abort)
        echo "Aborted by user."
        exit 1
        ;;
      *)
        echo "Please type 'done' or 'abort'."
        ;;
    esac
  done
}

run_step() {
  local title="$1"
  shift
  echo
  echo "[RUN] ${title}"
  "$@"
}

as_root() {
  if [[ -n "$SUDO" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

set_kv() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped
  escaped="$(printf '%s' "$value" | sed -e 's/[\\&]/\\\\&/g')"

  if [[ ! -f "$file" ]]; then
    echo "Missing file: $file"
    exit 1
  fi

  if grep -qE "^${key}=" "$file"; then
    sed -i -E "s#^${key}=.*#${key}=${escaped}#" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

openclaw_configure_backend() {
  case "$OPENCLAW_BACKEND" in
    openai)
      local key="${OPENAI_API_KEY:-}"
      if [[ -z "$key" ]]; then
        read -r -s -p "Enter OPENAI_API_KEY (input hidden): " key
        echo
      fi
      if [[ -z "$key" ]]; then
        echo "OPENAI_API_KEY is required for OPENCLAW_BACKEND=openai"
        exit 1
      fi

      if [[ -n "$OPENCLAW_MODEL" ]]; then
        run_step "Configure OpenClaw for OpenAI (${OPENCLAW_MODEL})" env OPENAI_API_KEY="$key" MODEL="$OPENCLAW_MODEL" ./scripts/connect-clawdbot-openai.sh
      else
        run_step "Configure OpenClaw for OpenAI (default model)" env OPENAI_API_KEY="$key" ./scripts/connect-clawdbot-openai.sh
      fi
      ;;
    anthropic)
      local key="${ANTHROPIC_API_KEY:-}"
      if [[ -z "$key" ]]; then
        read -r -s -p "Enter ANTHROPIC_API_KEY (input hidden): " key
        echo
      fi
      if [[ -z "$key" ]]; then
        echo "ANTHROPIC_API_KEY is required for OPENCLAW_BACKEND=anthropic"
        exit 1
      fi

      if [[ -n "$OPENCLAW_MODEL" ]]; then
        run_step "Configure OpenClaw for Anthropic (${OPENCLAW_MODEL})" env ANTHROPIC_API_KEY="$key" MODEL="$OPENCLAW_MODEL" ./scripts/connect-clawdbot-anthropic.sh
      else
        run_step "Configure OpenClaw for Anthropic (default model)" env ANTHROPIC_API_KEY="$key" ./scripts/connect-clawdbot-anthropic.sh
      fi
      ;;
    local)
      run_step "Install local model runtime" ./scripts/install-local-llm.sh
      if [[ -n "$OPENCLAW_MODEL" ]]; then
        run_step "Configure OpenClaw for local model (${OPENCLAW_MODEL})" env MODEL="$OPENCLAW_MODEL" ./scripts/connect-clawdbot-local.sh
      else
        run_step "Configure OpenClaw for local model (default)" ./scripts/connect-clawdbot-local.sh
      fi
      ;;
    skip)
      echo
      echo "[SKIP] Skipping OpenClaw model/provider wiring."
      ;;
  esac
}

install_homeassistant_host_prereqs() {
  as_root apt update
  as_root apt install -y dbus bluez
  as_root systemctl enable --now dbus bluetooth
}

echo "Master setup starting in: $ROOT_DIR"
echo "Using LAN_IP=${LAN_IP}, LAN_CIDR=${LAN_CIDR}, ROOT_DOMAIN=${ROOT_DOMAIN}, ACME_EMAIL=${ACME_EMAIL}"
echo "OpenClaw backend: ${OPENCLAW_BACKEND}"
echo "Expose Home Assistant publicly: ${EXPOSE_HOMEASSISTANT}"

manual_checkpoint \
  "Preflight confirmations" \
  "Reserve a static DHCP lease for this host at ${LAN_IP} in your router." \
  "Confirm you can SSH with keys before hardening." \
  "Confirm your DNS provider can create records for ${ROOT_DOMAIN}."

run_step "Install Docker engine + compose plugin" ./scripts/install-docker-host.sh
run_step "Install Home Assistant host prerequisites (DBus/Bluetooth)" install_homeassistant_host_prereqs
run_step "Create host directories and proxy network" ./scripts/bootstrap-host.sh
run_step "Prepare shared media directories for Nextcloud/Navidrome/Audiobookshelf" ./scripts/prepare-shared-media.sh
run_step "Create missing .env files from examples" ./scripts/init-env.sh

echo
echo "[RUN] Apply proxy/domain defaults to env files"
set_kv proxy/.env ACME_EMAIL "$ACME_EMAIL"
set_kv proxy/.env ROOT_DOMAIN "$ROOT_DOMAIN"
set_kv nextcloud/.env NEXTCLOUD_TRUSTED_DOMAINS "nc.${ROOT_DOMAIN}"

manual_checkpoint \
  "Edit all stack .env files" \
  "Open and review every */.env file and replace all placeholder secrets." \
  "At minimum, set strong passwords for Nextcloud and Immich databases/admin users." \
  "Keep image tags pinned unless intentionally upgrading."

manual_checkpoint \
  "Router configuration required" \
  "Create router port forwards: TCP 80 -> ${LAN_IP}:80 and TCP 443 -> ${LAN_IP}:443." \
  "Do NOT forward OpenClaw ports 18789/18790." \
  "Disable UPnP mappings you do not want."

manual_checkpoint \
  "Host firewall configuration required" \
  "Ensure host firewall allows 80/tcp and 443/tcp." \
  "Restrict SSH (22/tcp) to LAN CIDR ${LAN_CIDR}." \
  "Ensure 18789/tcp and 18790/tcp are denied from external networks."

manual_checkpoint \
  "DNS records required" \
  "Create A records to your WAN IP for: @, nc, immich, jellyfin, jellyseerr, calibre, navidrome, audiobookshelf, mollysocket (and optional ha)." \
  "Do NOT create any DNS record for OpenClaw."

run_step "Start all Docker stacks" ./scripts/up-all.sh
run_step "Install/refresh OpenClaw host service" ./scripts/install-openclaw-host.sh

manual_checkpoint \
  "Nextcloud media mounts" \
  "In Nextcloud External storage, use container paths: /media/music, /media/audiobooks, /media/podcasts." \
  "Do NOT use host paths like /srv/media/... inside the Nextcloud UI."

manual_checkpoint \
  "Edit OpenClaw env file" \
  "Edit /etc/openclaw/openclaw.env and set OPENCLAW_GATEWAY_TOKEN + provider credentials."

openclaw_configure_backend

run_step "Run OpenClaw onboarding helper" ./scripts/openclaw-onboard.sh

manual_checkpoint \
  "Finalize OpenClaw onboarding" \
  "Complete the onboarding URL/token flow printed by the previous command." \
  "Validate your Telegram integration after onboarding."

if [[ "$EXPOSE_HOMEASSISTANT" == "true" ]]; then
  manual_checkpoint \
    "Home Assistant public access" \
    "Confirm you want Home Assistant exposed at https://ha.${ROOT_DOMAIN} through Caddy." \
    "Ensure DNS A record for ha.${ROOT_DOMAIN} exists."
  run_step "Enable Home Assistant public proxy settings" ./scripts/enable-ha-public.sh
fi

run_step "Run security checks" env LAN_IP="$LAN_IP" LAN_CIDR="$LAN_CIDR" ./scripts/security-check.sh

echo
echo "Master setup complete."
echo "Validate app endpoints:"
echo " - https://nc.${ROOT_DOMAIN}"
echo " - https://immich.${ROOT_DOMAIN}"
echo " - https://jellyfin.${ROOT_DOMAIN}"
echo " - https://navidrome.${ROOT_DOMAIN}"
echo " - https://audiobookshelf.${ROOT_DOMAIN}"
