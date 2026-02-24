#!/usr/bin/env bash
set -euo pipefail

BASE_MODEL="${BASE_MODEL:-qwen2.5:3b}"
MODEL_ALIAS="${MODEL_ALIAS:-openai/qwen2.5:3b}"

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

echo "Installing local model runtime (Ollama)"
if ! command -v curl >/dev/null 2>&1; then
  as_root apt update
  as_root apt install -y curl
fi

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

echo "Enabling Ollama service"
as_root systemctl enable --now ollama

echo "Pulling model: $BASE_MODEL"
ollama pull "$BASE_MODEL"

echo "Creating OpenAI-compatible model alias: $MODEL_ALIAS"
ollama cp "$BASE_MODEL" "$MODEL_ALIAS"

echo "Verifying local inference endpoint"
if command -v curl >/dev/null 2>&1; then
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null
fi

echo
echo "Local model runtime ready."
echo "Installed base model: $BASE_MODEL"
echo "Installed alias model: $MODEL_ALIAS"
echo "Next step: ./scripts/connect-clawdbot-local.sh"
