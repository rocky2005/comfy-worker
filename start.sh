#!/bin/bash

echo "========================================"
echo " ComfyUI Worker Startup"
echo "========================================"

# ── ComfyS3 Config ────────────────────────────────────────────────────────────
if [ -d "/comfyui/custom_nodes/ComfyS3" ]; then
    cat > /comfyui/custom_nodes/ComfyS3/.env << ENVEOF
S3_REGION=auto
S3_ACCESS_KEY=${BUCKET_ACCESS_KEY_ID}
S3_SECRET_KEY=${BUCKET_SECRET_ACCESS_KEY}
S3_BUCKET_NAME=${BUCKET_NAME}
S3_INPUT_DIR=inputs
S3_OUTPUT_DIR=outputs
S3_ENDPOINT_URL=${BUCKET_ENDPOINT_URL}
ENVEOF
    echo "ComfyS3 configured"
fi

# ── Ollama ────────────────────────────────────────────────────────────────────
export OLLAMA_MODELS=/tmp/ollama
mkdir -p /tmp/ollama

# Start Ollama in background — don't block startup
ollama serve &
sleep 3
ollama pull llama3.2 &
echo "Ollama starting in background..."

# ── Model Downloads ───────────────────────────────────────────────────────────
# Run in background — ComfyUI starts immediately
# First job may fail if models aren't ready yet — that's expected
/download_models.sh &
DOWNLOAD_PID=$!
echo "Model downloads started in background (PID: $DOWNLOAD_PID)"
echo "First job will fail if models aren't ready — this is normal on first boot"

# ── Start ComfyUI ─────────────────────────────────────────────────────────────
echo "Starting ComfyUI..."
exec python -u /start.py
