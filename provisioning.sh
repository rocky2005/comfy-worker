#!/bin/bash

# Vast.ai ComfyUI Provisioning Script
# Installs custom nodes + downloads all models
# Runs on every worker cold start — safe to re-run (skips existing files)

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE_DIR}/ComfyUI"
NODES_DIR="${COMFYUI_DIR}/custom_nodes"
MODELS_DIR="${COMFYUI_DIR}/models"
VOLUME_DIR="${WORKSPACE_DIR}/models"

export HF_HUB_ENABLE_HF_TRANSFER=1

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# ── Helper: download from URL ─────────────────────────────────────────────────
download_url() {
    local url=$1
    local dest=$2
    if [ -f "$dest" ]; then log "✓ $(basename $dest)"; return 0; fi
    log "↓ $(basename $dest)..."
    mkdir -p "$(dirname $dest)"
    wget -q --show-progress -O "$dest" "$url"
    log "✓ Done: $(basename $dest)"
}

# ── Helper: download from R2 ──────────────────────────────────────────────────
download_r2() {
    local r2_path=$1
    local dest=$2
    if [ -f "$dest" ]; then log "✓ $(basename $dest)"; return 0; fi
    local url="${R2_PUBLIC_URL}/models/${r2_path}"
    log "↓ $(basename $dest) from R2..."
    mkdir -p "$(dirname $dest)"
    wget -q --show-progress -O "$dest" "$url"
    log "✓ Done: $(basename $dest)"
}

# ── Activate venv ─────────────────────────────────────────────────────────────
if [ -f /venv/main/bin/activate ]; then
    source /venv/main/bin/activate
fi

pip install hf_transfer huggingface_hub --quiet --no-cache-dir

# ── Install Ollama ────────────────────────────────────────────────────────────
if ! command -v ollama &> /dev/null; then
    log "Installing Ollama..."
    apt-get install -y zstd curl > /dev/null 2>&1
    curl -fsSL https://ollama.ai/install.sh | sh
fi

export OLLAMA_MODELS="${WORKSPACE_DIR}/ollama"
mkdir -p "${OLLAMA_MODELS}"
ollama serve &
sleep 5
if ! ollama list 2>/dev/null | grep -q "llama3.2"; then
    log "Pulling llama3.2..."
    ollama pull llama3.2
fi

# ── Custom Nodes ──────────────────────────────────────────────────────────────
log "Installing custom nodes..."
mkdir -p "$NODES_DIR"
cd "$NODES_DIR"

clone_node() {
    local url=$1
    local name=$(basename $url)
    if [ -d "$name" ]; then log "✓ Already installed: $name"; return 0; fi
    log "Cloning $name..."
    git clone --depth 1 "$url" "$name" || log "WARNING: Failed to clone $name"
}

clone_node https://github.com/kijai/ComfyUI-WanVideoWrapper
clone_node https://github.com/kijai/ComfyUI-WanAnimatePreprocess
clone_node https://github.com/kijai/ComfyUI-SCAIL-pose
clone_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
clone_node https://github.com/Lightricks/ComfyUI-LTXVideo
clone_node https://github.com/kijai/ComfyUI-KJNodes
clone_node https://github.com/kijai/ComfyUI-Florence2
clone_node https://github.com/ltdrdata/ComfyUI-Impact-Pack
clone_node https://github.com/vantagewithai/Vantage-HunyuanFoley
clone_node https://github.com/kael558/ComfyUI-GGUF-FantasyTalking
clone_node https://github.com/city96/ComfyUI-GGUF
clone_node https://github.com/Starnodes2024/ComfyUI_StarNodes
clone_node https://github.com/cubiq/ComfyUI_IPAdapter_plus
clone_node https://github.com/Fannovel16/comfyui_controlnet_aux
clone_node https://github.com/rgthree/rgthree-comfy
clone_node https://github.com/jags111/efficiency-nodes-comfyui
clone_node https://github.com/pythongosssss/ComfyUI-Custom-Scripts
clone_node https://github.com/cubiq/ComfyUI_essentials
clone_node https://github.com/WASasquatch/was-node-suite-comfyui
clone_node https://github.com/TemryL/ComfyS3
clone_node https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI
clone_node https://github.com/1038lab/ComfyUI-QwenVL
clone_node https://github.com/thedyze/save-image-extended-comfyui
clone_node https://github.com/aining2022/ComfyUI_Swwan
clone_node https://github.com/comfyui_nvidia_rtx_nodes

# Install requirements for all nodes
log "Installing node requirements..."
find "$NODES_DIR" -name "requirements.txt" | while read req; do
    pip install -r "$req" --quiet --no-cache-dir 2>&1 || \
    log "WARNING: Some packages failed in $req"
done

# Configure ComfyS3 for R2
if [ -d "$NODES_DIR/ComfyS3" ]; then
    cat > "$NODES_DIR/ComfyS3/.env" << EOF
S3_REGION=auto
S3_ACCESS_KEY=${S3_ACCESS_KEY_ID}
S3_SECRET_KEY=${S3_SECRET_ACCESS_KEY}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
S3_INPUT_DIR=inputs
S3_OUTPUT_DIR=outputs
S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
EOF
fi

log "✓ All nodes installed"

# ── Model Storage: Symlink volume to ComfyUI ──────────────────────────────────
log "Setting up model storage..."

mkdir -p "${VOLUME_DIR}"/{checkpoints,diffusion_models,text_encoders,vae,loras,controlnet,clip_vision,unet,onnx}
mkdir -p "${VOLUME_DIR}/loras/Z-Image/char"
mkdir -p "${VOLUME_DIR}/diffusion_models/Z-Image"

for folder in checkpoints diffusion_models text_encoders vae loras controlnet clip_vision unet onnx; do
    if [ ! -L "${MODELS_DIR}/$folder" ] && [ -d "${MODELS_DIR}/$folder" ]; then
        cp -r "${MODELS_DIR}/$folder"/* "${VOLUME_DIR}/$folder/" 2>/dev/null || true
        rm -rf "${MODELS_DIR}/$folder"
    fi
    ln -sfn "${VOLUME_DIR}/$folder" "${MODELS_DIR}/$folder"
done

# ── Download Models ───────────────────────────────────────────────────────────

log ""; log "── Shared Flux ──"
download_url "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "${VOLUME_DIR}/vae/ae.safetensors"
download_url "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors" \
    "${VOLUME_DIR}/text_encoders/t5xxl_fp16.safetensors"
download_url "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "${VOLUME_DIR}/text_encoders/clip_l.safetensors"

log ""; log "── Face Detailer (SRPO) ──"
download_url "https://huggingface.co/wikeeyang/SRPO-for-ComfyUI/resolve/main/SRPO-fp8_e4m3fn.safetensors" \
    "${VOLUME_DIR}/diffusion_models/SRPO-fp8_e4m3fn.safetensors"

log ""; log "── Flux 2 Dev ──"
download_url "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" \
    "${VOLUME_DIR}/diffusion_models/flux2_dev_fp8mixed.safetensors"
download_url "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors" \
    "${VOLUME_DIR}/text_encoders/mistral_3_small_flux2_bf16.safetensors"
download_url "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "${VOLUME_DIR}/vae/flux2-vae.safetensors"

log ""; log "── Z-Anime ──"
download_url "https://huggingface.co/SeeSee21/Z-Anime/resolve/main/diffusion_models/z-anime-distill-8step-bf16.safetensors" \
    "${VOLUME_DIR}/diffusion_models/Z-Image/z-anime-distill-8step-bf16.safetensors"
download_url "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
    "${VOLUME_DIR}/text_encoders/qwen_3_4b.safetensors"

log ""; log "── Z-Image LoRAs ──"
download_url "https://huggingface.co/kayte0342/z_image_loras/resolve/main/z_skin_detail.safetensors" \
    "${VOLUME_DIR}/loras/Z-Image/z_skin_detail.safetensors"
download_r2 "Z-Image/char/excinderella_marta_kowalczyk_2026_v1_000005000.safetensors" \
    "${VOLUME_DIR}/loras/Z-Image/char/excinderella_marta_kowalczyk_2026_v1_000005000.safetensors"

log ""; log "── Wan Animate ──"
download_url "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
    "${VOLUME_DIR}/clip_vision/clip_vision_h.safetensors"
download_url "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "${VOLUME_DIR}/vae/Wan2_1_VAE_bf16.safetensors"
download_url "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "${VOLUME_DIR}/text_encoders/umt5-xxl-enc-bf16.safetensors"
download_url "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" \
    "${VOLUME_DIR}/controlnet/Wan21_Uni3C_controlnet_fp16.safetensors"
download_url "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SCAIL/Wan21-14B-SCAIL-preview_fp8_e4m3fn_scaled_KJ.safetensors" \
    "${VOLUME_DIR}/diffusion_models/Wan21-14B-SCAIL-preview_fp8_e4m3fn_scaled_KJ.safetensors"
download_url "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
    "${VOLUME_DIR}/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
download_url "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" \
    "${VOLUME_DIR}/onnx/yolov10m.onnx"
download_url "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx" \
    "${VOLUME_DIR}/onnx/vitpose-l-wholebody.onnx"
download_url "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" \
    "${VOLUME_DIR}/onnx/vitpose_h_wholebody_model.onnx"
download_url "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" \
    "${VOLUME_DIR}/onnx/vitpose_h_wholebody_data.bin"

log ""
log "════════════════════════════════"
log " Provisioning complete"
log "════════════════════════════════"
