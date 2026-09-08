# Hướng dẫn triển khai TITOPS CHAT (AnythingLLM)

Triển khai 1 lệnh với Docker, không cần cài Ollama local nếu dùng API cloud.

## Yêu cầu
- Ubuntu 22.04 / Docker 24+ / 10GB RAM + 8GB swap (nếu dùng Ollama 7b) / 30GB disk trống
- Git

## 2 bước triển khai

### 1. Thêm file `.env` vào thư mục `docker/`

```bash
git clone https://github.com/Tmh3101/titops-anything-llm.git
cd titops-anything-llm

# Tạo .env từ template (file này đã gitignore, không commit)
cp docker/.env.example docker/.env
nano docker/.env
```

**Chọn 1 cấu hình trong `docker/.env`:**

**A. Chỉ web, không model local (nhẹ nhất) – cấu hình LLM trên UI sau:**
```ini
SERVER_PORT=3001
STORAGE_DIR="/app/server/storage"
# để trống LLM_PROVIDER, sẽ cấu hình tại http://IP:3001 -> Settings -> LLM Preference
EMBEDDING_ENGINE=native
EMBEDDING_MODEL_PREF=Xenova/all-MiniLM-L6-v2
VECTOR_DB=lancedb
```

**B. Local Ollama (CPU, 1 lệnh):**
```ini
SERVER_PORT=3001
LLM_PROVIDER=ollama
OLLAMA_BASE_PATH=http://ollama:11434
OLLAMA_MODEL_PREF=llama3.1:8b   # hoặc qwen2.5:7b-instruct-q4_K_M
EMBEDDING_ENGINE=native
VECTOR_DB=lancedb
```

**C. Gemini API (không cần GPU):**
```ini
LLM_PROVIDER=gemini
GEMINI_API_KEY=AIza...
GEMINI_LLM_MODEL_PREF=gemini-2.0-flash
EMBEDDING_ENGINE=native
VECTOR_DB=lancedb
```

> Tạo swap nếu dùng 7b/8b: `sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`

### 2. Chạy `./deploy.sh` tại thư mục gốc

```bash
chmod +x deploy.sh
./deploy.sh
```

Script sẽ:
- Tự tạo `docker/.env` nếu chưa có
- Kiểm tra Docker, RAM/swap
- `docker compose -f docker/docker-compose.yml up -d --build` (lần đầu 5-10 phút, tải model ~5GB nếu dùng Ollama)
- Chờ Ollama healthy và in URL

**Kiểm tra:**
```bash
docker compose -f docker/docker-compose.yml ps
curl http://localhost:3001/api/ping
# Mở http://<IP_SERVER>:3001
```

**Đổi model sau này:** sửa `OLLAMA_MODEL_PREF` trong `docker/.env` rồi chạy lại `./deploy.sh`.

**Dừng:** `docker compose -f docker/docker-compose.yml down`
**Logs:** `docker compose -f docker/docker-compose.yml logs -f`
