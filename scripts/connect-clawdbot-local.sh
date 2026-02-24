#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-ollama/gpt-4o-mini}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-${BASE_URL:-http://127.0.0.1:11434}}"
ENV_FILE="${ENV_FILE:-/etc/openclaw/openclaw.env}"
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

set_kv OLLAMA_API_KEY ollama-local
set_kv OPENAI_API_KEY ""
set_kv OPENAI_BASE_URL ""
set_kv OPENAI_MODEL ""
set_kv ANTHROPIC_API_KEY ""
set_kv GEMINI_API_KEY ""

# If onboarding persisted a bare model name in OpenClaw runtime config,
# rewrite it to the provider-qualified model to prevent anthropic fallback.
if [[ "$MODEL" == */* ]]; then
  bare_model="${MODEL#*/}"
  if [[ -d /srv/openclaw/.openclaw ]]; then
    search_escaped="$(printf '%s' "$bare_model" | sed -e 's/[][(){}.^$?+*|\\]/\\&/g')"
    replace_escaped="$(printf '%s' "$MODEL" | sed -e 's/[\\&]/\\\\&/g')"
    patched_files=0
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      as_root sed -i -E "s#${search_escaped}#${replace_escaped}#g" "$f"
      patched_files=$((patched_files + 1))
    done < <(as_root grep -RIlF --binary-files=without-match "$bare_model" /srv/openclaw/.openclaw 2>/dev/null || true)

    if (( patched_files > 0 )); then
      echo "Patched $patched_files OpenClaw runtime config file(s) under /srv/openclaw/.openclaw"
    fi
  fi
fi

# Backward-compat cleanup: replace known older local-model values that trigger fallback.
if [[ -d /srv/openclaw/.openclaw ]]; then
  patched_legacy=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    as_root sed -i -E \
      "s#anthropic/qwen2\\.5:3b#${MODEL}#g; s#openai/qwen2\\.5:3b#${MODEL}#g; s#\"qwen2\\.5:3b\"#\"${MODEL}\"#g" \
      "$f"
    patched_legacy=$((patched_legacy + 1))
  done < <(as_root grep -RIlE --binary-files=without-match 'qwen2\.5:3b|anthropic/qwen2\.5:3b|openai/qwen2\.5:3b' /srv/openclaw/.openclaw 2>/dev/null || true)

  if (( patched_legacy > 0 )); then
    echo "Patched $patched_legacy legacy qwen2.5:3b reference(s) under /srv/openclaw/.openclaw"
  fi
fi

# Ensure persisted OpenClaw runtime config keeps model/workspace sane.
# Provider credentials/endpoints are read from /etc/openclaw/openclaw.env for this OpenClaw version.
runtime_cfg="/srv/openclaw/.openclaw/openclaw.json"
if [[ -f "$runtime_cfg" ]]; then
  as_root python3 - "$runtime_cfg" "$MODEL" <<'PY'
import json
import sys

cfg_path, model = sys.argv[1], sys.argv[2]
with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

agents = cfg.setdefault("agents", {}).setdefault("defaults", {})
agents.setdefault("model", {})["primary"] = model
# Keep allowlist aligned with the chosen local model only,
# otherwise stale cloud-only entries can force unexpected provider selection.
agents["models"] = {model: {}}

# Keep runtime data off /var partition.
if agents.get("workspace", "").startswith("/var/lib/openclaw/"):
    agents["workspace"] = "/srv/openclaw/.openclaw/workspace"

# Compatibility: this OpenClaw schema does not accept top-level "providers".
cfg.pop("providers", None)

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  echo "Patched runtime provider/model config in $runtime_cfg"
fi

as_root chown root:openclaw "$ENV_FILE"
as_root chmod 640 "$ENV_FILE"

echo "Restarting ${OPENCLAW_UNIT}.service"
as_root systemctl restart "${OPENCLAW_UNIT}.service"
as_root systemctl --no-pager --full status "${OPENCLAW_UNIT}.service" | sed -n '1,25p'

echo "Testing local model endpoint"
if command -v curl >/dev/null 2>&1; then
  test_base="${OLLAMA_BASE_URL%/}"
  test_base="${test_base%/v1}"
  curl -fsS "${test_base}/api/tags" >/dev/null
  echo "Local model API is reachable at ${test_base}"
fi

echo
echo "OpenClaw/ClawdBot now configured for local model."
echo "Model: $MODEL"
echo "Ollama URL: $OLLAMA_BASE_URL"
