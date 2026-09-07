#!/usr/bin/env bash
set -euo pipefail

# Deploy AnythingLLM + Ollama (CPU-only) - config đọc từ docker/.env
# Usage: chmod +x deploy.sh && ./deploy.sh
# Đổi model: sửa OLLAMA_MODEL_PREF trong docker/.env rồi chạy lại ./deploy.sh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="docker/docker-compose.yml"
ENV_FILE="docker/.env"

echo "================================================================"
echo " AnythingLLM Deploy - CPU Only (config từ $ENV_FILE)"
echo "================================================================"

# 1. Check docker
if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker not found. Install: https://docs.docker.com/engine/install/ubuntu/"
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin not found."
  exit 1
fi

# 2. Ensure env file exists (auto-create from local template if missing - since docker/.env is gitignored)
if [[ ! -f "$ROOT_DIR/$ENV_FILE" ]]; then
  echo "[info] $ENV_FILE not found, creating from local template..."
  cat > "$ROOT_DIR/$ENV_FILE" <<'ENVEOF'
###############################################################################
# AnythingLLM - One-command local stack (CPU-only 9.7GB RAM, no GPU)
# File này được mount vào /app/server/.env trong container
# Chỉ cần: docker compose -f docker/docker-compose.yml up -d
# Đổi model: sửa OLLAMA_MODEL_PREF bên dưới rồi restart
###############################################################################
SERVER_PORT=3001
STORAGE_DIR="/app/server/storage"
UID=1000
GID=1000
LLM_PROVIDER=ollama
OLLAMA_BASE_PATH=http://ollama:11434
OLLAMA_MODEL_PREF=qwen2.5:3b-instruct-q4_K_M
OLLAMA_MODEL_TOKEN_LIMIT=4096
EMBEDDING_ENGINE=native
EMBEDDING_MODEL_PREF=Xenova/all-MiniLM-L6-v2
VECTOR_DB=lancedb
WHISPER_PROVIDER=local
TTS_PROVIDER=native
STT_PROVIDER=native
AGENT_MAX_TOOL_CALLS=6
AGENT_SKILL_RERANKER_ENABLED=true
AGENT_SKILL_RERANKER_TOP_N=12
ENVEOF
  echo "[ok] Created $ENV_FILE with defaults (qwen2.5:3b). Sửa file này nếu muốn model khác."
fi

# 3. Load config từ .env (không hard-code trong sh)
set -a
# shellcheck disable=SC1090
source <(grep -v '^#' "$ROOT_DIR/$ENV_FILE" | grep -v '^\s*$' | sed 's/\r$//')
set +a

OLLAMA_MODEL_PREF="${OLLAMA_MODEL_PREF:-qwen2.5:3b-instruct-q4_K_M}"
SERVER_PORT="${SERVER_PORT:-3001}"

echo "[info] Config từ $ENV_FILE:"
echo "  LLM_PROVIDER=$LLM_PROVIDER"
echo "  OLLAMA_MODEL_PREF=$OLLAMA_MODEL_PREF"
echo "  EMBEDDING_ENGINE=$EMBEDDING_ENGINE"
echo "  VECTOR_DB=$VECTOR_DB"
echo "  SERVER_PORT=$SERVER_PORT"

# 4. Check swap nếu model nặng
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
SWAP_GB=$(free -g | awk '/^Swap:/{print $2}')
if [[ "$OLLAMA_MODEL_PREF" == *"7b"* || "$OLLAMA_MODEL_PREF" == *"14b"* || "$OLLAMA_MODEL_PREF" == *"32b"* ]]; then
  if [[ "$SWAP_GB" -eq 0 ]]; then
    echo ""
    echo "[warn] Model $OLLAMA_MODEL_PREF với RAM ${TOTAL_RAM_GB}GB và 0 swap -> dễ OOM."
    echo "  Khuyến nghị: sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
    echo "  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
    echo ""
    read -p "Tiếp tục anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
  fi
fi

# 5. Up
echo "[info] Building and starting stack (lần đầu pull model ~2GB, 5-10 phút trên CPU)..."
docker compose -f "$COMPOSE_FILE" up -d --build

echo ""
echo "[info] Waiting for Ollama healthy..."
for i in {1..60}; do
  if docker inspect --format='{{json .State.Health.Status}}' anythingllm-ollama 2>/dev/null | grep -q "healthy"; then
    echo "[ok] Ollama healthy"
    break
  fi
  echo "  ... $i/60"
  sleep 5
done

echo "[info] Waiting for model pull (ollama-init)..."
docker logs -f anythingllm-ollama-init 2>&1 | head -n 100 || true

echo ""
echo "[info] Stack status:"
docker compose -f "$COMPOSE_FILE" ps
echo ""
echo "================================================================"
echo " DONE! Open http://$(curl -s ifconfig.me 2>/dev/null || echo '<server-ip>'):${SERVER_PORT}"
echo " Logs: docker compose -f $COMPOSE_FILE logs -f"
echo " Stop: docker compose -f $COMPOSE_FILE down"
echo " Đổi model: sửa OLLAMA_MODEL_PREF trong $ENV_FILE rồi chạy lại ./deploy.sh"
echo "================================================================"
