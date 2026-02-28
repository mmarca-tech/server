#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-anthropic/claude-sonnet-4-5}"
ENV_FILE="${ENV_FILE:-/etc/openclaw/openclaw.env}"
TELEGRAM_DM_POLICY="${TELEGRAM_DM_POLICY:-pairing}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
DISABLE_OLLAMA_DROPINS="${DISABLE_OLLAMA_DROPINS:-true}"
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

ensure_openclaw_service_access() {
  local changed=0
  local dropin_dir="/etc/systemd/system/${OPENCLAW_UNIT}.service.d"
  local dropin_file="${dropin_dir}/10-docker-access.conf"
  local desired_dropin current_dropin
  desired_dropin=$'[Service]\nSupplementaryGroups=docker\nEnvironment=DOCKER_HOST=unix:///var/run/docker.sock\n'

  if ! as_root systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${OPENCLAW_UNIT}.service"; then
    echo "Missing ${OPENCLAW_UNIT}.service"
    echo "Run ./scripts/install-openclaw-host.sh first."
    exit 1
  fi

  if ! id -u openclaw >/dev/null 2>&1; then
    echo "Missing system user: openclaw"
    echo "Run ./scripts/install-openclaw-host.sh first."
    exit 1
  fi

  if ! getent group docker >/dev/null 2>&1; then
    as_root groupadd docker
    changed=1
  fi

  if ! id -nG openclaw | tr ' ' '\n' | grep -qx docker; then
    as_root usermod -aG docker openclaw
    changed=1
  fi

  current_dropin="$(as_root cat "$dropin_file" 2>/dev/null || true)"
  if [[ "${current_dropin}"$'\n' != "$desired_dropin" ]]; then
    as_root mkdir -p "$dropin_dir"
    printf '%s' "$desired_dropin" | as_root tee "$dropin_file" >/dev/null
    changed=1
  fi

  if (( changed > 0 )); then
    as_root systemctl daemon-reload
  fi
}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Run ./scripts/install-openclaw-host.sh first."
  exit 1
fi

if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "Missing ANTHROPIC_API_KEY."
  echo "Run with: ANTHROPIC_API_KEY='your-key' ./scripts/connect-clawdbot-anthropic.sh"
  exit 1
fi

ensure_openclaw_service_access

if [[ ! -S /var/run/docker.sock ]]; then
  echo "Warning: /var/run/docker.sock is not present. Start Docker if OpenClaw will use Docker tools."
fi

set_kv() {
  local key="$1"
  local value="$2"
  local escaped_value
  escaped_value="$(printf '%s' "$value" | sed -e 's/[\\&]/\\\\&/g')"

  if as_root grep -qE "^${key}=" "$ENV_FILE"; then
    as_root sed -i -E "s#^${key}=.*#${key}=${escaped_value}#" "$ENV_FILE"
  else
    echo "${key}=${value}" | as_root tee -a "$ENV_FILE" >/dev/null
  fi
}

backup_file="${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"
as_root cp "$ENV_FILE" "$backup_file"
echo "Backed up env file to: $backup_file"

set_kv ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
set_kv OPENAI_API_KEY ""
set_kv OPENAI_MODEL ""
set_kv OPENAI_BASE_URL ""
set_kv OLLAMA_API_KEY ""
set_kv GEMINI_API_KEY ""

if [[ "$DISABLE_OLLAMA_DROPINS" == "true" ]]; then
  removed_dropins=0
  for f in "/etc/systemd/system/${OPENCLAW_UNIT}.service.d/10-ollama.conf" "/etc/systemd/system/${OPENCLAW_UNIT}.service.d/20-ollama-env.conf"; do
    if as_root test -f "$f"; then
      as_root rm -f "$f"
      removed_dropins=$((removed_dropins + 1))
    fi
  done
  if (( removed_dropins > 0 )); then
    echo "Removed $removed_dropins Ollama-specific OpenClaw drop-in file(s)"
    as_root systemctl daemon-reload
  fi
fi

runtime_cfg="/srv/openclaw/.openclaw/openclaw.json"
if as_root test -f "$runtime_cfg"; then
  as_root python3 - "$runtime_cfg" "$MODEL" "$TELEGRAM_DM_POLICY" <<'PY'
import json
import sys

cfg_path, model, dm_policy = sys.argv[1], sys.argv[2], sys.argv[3]
valid_dm_policies = {"pairing", "allowlist", "open", "disabled"}

with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

agents = cfg.setdefault("agents", {}).setdefault("defaults", {})
agents.setdefault("model", {})["primary"] = model
agents["models"] = {model: {}}

# Keep runtime data off /var partition.
if agents.get("workspace", "").startswith("/var/lib/openclaw/"):
    agents["workspace"] = "/srv/openclaw/.openclaw/workspace"

# Compatibility: this OpenClaw schema does not accept top-level "providers".
cfg.pop("providers", None)

telegram = cfg.setdefault("channels", {}).setdefault("telegram", {})
if dm_policy in valid_dm_policies:
    telegram["dmPolicy"] = dm_policy
elif telegram.get("dmPolicy") not in valid_dm_policies:
    telegram["dmPolicy"] = "pairing"

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  echo "Patched runtime model config in $runtime_cfg"
fi

as_root chown root:openclaw "$ENV_FILE"
as_root chmod 640 "$ENV_FILE"

echo "Restarting ${OPENCLAW_UNIT}.service"
as_root systemctl restart "${OPENCLAW_UNIT}.service"
as_root systemctl --no-pager --full status "${OPENCLAW_UNIT}.service" | sed -n '1,25p'

echo
echo "OpenClaw/ClawdBot now configured for Anthropic."
echo "Model: $MODEL"
echo "Telegram dmPolicy: $TELEGRAM_DM_POLICY"
