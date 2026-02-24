#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-qwen2.5:3b}"
BASE_URL="${BASE_URL:-http://127.0.0.1:11434/v1}"
ENV_FILE="${ENV_FILE:-/etc/openclaw/openclaw.env}"

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

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Run ./scripts/install-openclaw-host.sh first."
  exit 1
fi

set_kv() {
  local key="$1"
  local value="$2"
  local escaped_value
  escaped_value="$(printf '%s' "$value" | sed -e 's/[\\&/]/\\\\&/g')"

  if as_root grep -qE "^${key}=" "$ENV_FILE"; then
    as_root sed -i -E "s#^${key}=.*#${key}=${escaped_value}#" "$ENV_FILE"
  else
    echo "${key}=${value}" | as_root tee -a "$ENV_FILE" >/dev/null
  fi
}

backup_file="${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"
as_root cp "$ENV_FILE" "$backup_file"
echo "Backed up env file to: $backup_file"

set_kv OPENAI_API_KEY local
set_kv OPENAI_BASE_URL "$BASE_URL"
set_kv OPENAI_MODEL "$MODEL"
set_kv ANTHROPIC_API_KEY ""
set_kv GEMINI_API_KEY ""

as_root chown root:openclaw "$ENV_FILE"
as_root chmod 640 "$ENV_FILE"

echo "Restarting OpenClaw gateway"
as_root systemctl restart openclaw-gateway
as_root systemctl --no-pager --full status openclaw-gateway | sed -n '1,25p'

echo "Testing local model endpoint"
if command -v curl >/dev/null 2>&1; then
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null
  echo "Local model API is reachable at 127.0.0.1:11434"
fi

echo
echo "OpenClaw/ClawdBot now configured for local model."
echo "Model: $MODEL"
echo "Base URL: $BASE_URL"
