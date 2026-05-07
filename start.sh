#!/bin/bash
set -e

echo "========================================"
echo " ComfyUI Worker Startup"
echo "========================================"

# ── Ollama ────────────────────────────────────────────────────────────────────

echo "[1/4] Starting Ollama..."

# Store model on network volume so it persists across workers
export OLLAMA_MODELS=/runpod-volume/ollama
mkdir -p /runpod-volume/ollama

# Start Ollama service in background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
for i in $(seq 1 30); do
    if ollama list > /dev/null 2>&1; then
        echo "Ollama ready"
        break
    fi
    sleep 2
done

# Pull model only if not already cached on volume
if ! ollama list | grep -q "llama3.2"; then
    echo "Pulling llama3.2 (~2GB, first time only)..."
    ollama pull llama3.2
else
    echo "llama3.2 already cached, skipping"
fi

# ── Models ────────────────────────────────────────────────────────────────────

echo "[2/4] Checking models..."
/download_models.sh

# ── ComfyS3 Config ────────────────────────────────────────────────────────────

echo "[3/4] Configuring ComfyS3 (R2)..."
# Write .env file for ComfyS3 node using your RunPod env vars
cat > /comfyui/custom_nodes/ComfyS3/.env << EOF
S3_REGION=auto
S3_ACCESS_KEY=${BUCKET_ACCESS_KEY_ID}
S3_SECRET_KEY=${BUCKET_SECRET_ACCESS_KEY}
S3_BUCKET_NAME=${BUCKET_NAME}
S3_INPUT_DIR=inputs
S3_OUTPUT_DIR=outputs
S3_ENDPOINT_URL=${BUCKET_ENDPOINT_URL}
EOF
echo "ComfyS3 configured"

# ── Start Worker ──────────────────────────────────────────────────────────────

echo "[4/4] Starting ComfyUI worker..."
exec python -u /start.py
