#!/bin/bash

# Downloads all models directly from HuggingFace.
# Re-running is safe — skips files that already exist.
# Only excinderella LoRA needs R2 (custom trained, not public).

set -e

VOLUME="/runpod-volume"
COMFY_MODELS="/comfyui/models"

export HF_HUB_ENABLE_HF_TRANSFER=1

download_url() {
    local url=$1
    local dest=$2
    if [ -f "$dest" ]; then echo "  ✓ $(basename $dest)"; return 0; fi
    echo "  ↓ $(basename $dest)..."
    mkdir -p "$(dirname $dest)"
    wget -q --show-progress -O "$dest" "$url"
    echo "  ✓ Done"
}

download_r2() {
    local r2_path=$1
    local dest=$2
    if [ -f "$dest" ]; then echo "  ✓ $(basename $dest)"; return 0; fi
    local url="${R2_PUBLIC_URL}/models/${r2_path}"
    echo "  ↓ $(basename $dest) from R2..."
    mkdir -p "$(dirname $dest)"
    wget -q --show-progress -O "$dest" "$url"
    echo "  ✓ Done"
}

# ── Symlink model folders to persistent volume ────────────────────────────────

mkdir -p $VOLUME/models/{checkpoints,diffusion_models,text_encoders,vae,loras,controlnet,clip_vision,unet,onnx}
mkdir -p $VOLUME/models/loras/Z-Image/char
mkdir -p $VOLUME/models/diffusion_models/Z-Image

for folder in checkpoints diffusion_models text_encoders vae loras controlnet clip_vision unet onnx; do
    if [ ! -L "$COMFY_MODELS/$folder" ] && [ -d "$COMFY_MODELS/$folder" ]; then
        cp -r "$COMFY_MODELS/$folder"/* "$VOLUME/models/$folder/" 2>/dev/null || true
        rm -rf "$COMFY_MODELS/$folder"
    fi
    ln -sfn "$VOLUME/models/$folder" "$COMFY_MODELS/$folder"
done

# ── Shared Flux Models ────────────────────────────────────────────────────────
echo ""; echo "── Shared Flux ──"

download_url \
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "$VOLUME/models/vae/ae.safetensors"

download_url \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors" \
    "$VOLUME/models/text_encoders/t5xxl_fp16.safetensors"

download_url \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$VOLUME/models/text_encoders/clip_l.safetensors"

# ── Face Detailer / SRPO ──────────────────────────────────────────────────────
echo ""; echo "── Face Detailer (SRPO) ──"

download_url \
    "https://huggingface.co/wikeeyang/SRPO-for-ComfyUI/resolve/main/SRPO-fp8_e4m3fn.safetensors" \
    "$VOLUME/models/diffusion_models/SRPO-fp8_e4m3fn.safetensors"

# ── Flux 2 Dev ────────────────────────────────────────────────────────────────
echo ""; echo "── Flux 2 Dev ──"

download_url \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" \
    "$VOLUME/models/diffusion_models/flux2_dev_fp8mixed.safetensors"

download_url \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors" \
    "$VOLUME/models/text_encoders/mistral_3_small_flux2_bf16.safetensors"

download_url \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "$VOLUME/models/vae/flux2-vae.safetensors"

# ── Z-Anime ───────────────────────────────────────────────────────────────────
echo ""; echo "── Z-Anime ──"

download_url \
    "https://huggingface.co/SeeSee21/Z-Anime/resolve/main/diffusion_models/z-anime-distill-8step-bf16.safetensors" \
    "$VOLUME/models/diffusion_models/Z-Image/z-anime-distill-8step-bf16.safetensors"

download_url \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
    "$VOLUME/models/text_encoders/qwen_3_4b.safetensors"

# ── Z-Image LoRAs ─────────────────────────────────────────────────────────────
echo ""; echo "── Z-Image LoRAs ──"

download_url \
    "https://huggingface.co/kayte0342/z_image_loras/resolve/main/z_skin_detail.safetensors" \
    "$VOLUME/models/loras/Z-Image/z_skin_detail.safetensors"

# Custom trained LoRA — only one that needs R2
# Upload from: ComfyUI/models/loras/Z-Image/char/excinderella_...safetensors
download_r2 \
    "Z-Image/char/excinderella_marta_kowalczyk_2026_v1_000005000.safetensors" \
    "$VOLUME/models/loras/Z-Image/char/excinderella_marta_kowalczyk_2026_v1_000005000.safetensors"

# ── Wan Animate ───────────────────────────────────────────────────────────────
echo ""; echo "── Wan Animate ──"

download_url \
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
    "$VOLUME/models/clip_vision/clip_vision_h.safetensors"

download_url \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "$VOLUME/models/vae/Wan2_1_VAE_bf16.safetensors"

download_url \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$VOLUME/models/text_encoders/umt5-xxl-enc-bf16.safetensors"

download_url \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" \
    "$VOLUME/models/controlnet/Wan21_Uni3C_controlnet_fp16.safetensors"

download_url \
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SCAIL/Wan21-14B-SCAIL-preview_fp8_e4m3fn_scaled_KJ.safetensors" \
    "$VOLUME/models/diffusion_models/Wan21-14B-SCAIL-preview_fp8_e4m3fn_scaled_KJ.safetensors"

download_url \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
    "$VOLUME/models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

download_url \
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" \
    "$VOLUME/models/onnx/yolov10m.onnx"

download_url \
    "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx" \
    "$VOLUME/models/onnx/vitpose-l-wholebody.onnx"

download_url \
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" \
    "$VOLUME/models/onnx/vitpose_h_wholebody_model.onnx"

download_url \
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" \
    "$VOLUME/models/onnx/vitpose_h_wholebody_data.bin"

echo ""
echo "════════════════════════════════"
echo " All models ready"
echo "════════════════════════════════"
echo ""
echo "⚠  One model still needs manual R2 upload:"
echo "   excinderella_marta_kowalczyk_2026_v1_000005000.safetensors"
echo "   (custom-trained LoRA — not on HuggingFace)"
echo ""
