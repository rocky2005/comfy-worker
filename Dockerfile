FROM runpod/worker-comfyui:5.2.0-base

# System dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    wget \
    curl \
    zstd \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Install hf_transfer for faster HuggingFace downloads
RUN pip install hf_transfer huggingface_hub --no-cache-dir

# ── Custom Nodes ──────────────────────────────────────────────────────────────

# Prevent git from prompting for credentials on missing repos
ENV GIT_TERMINAL_PROMPT=0

# ── Custom Nodes ──────────────────────────────────────────────────────────────

RUN cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanAnimatePreprocess && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-SCAIL-pose && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    git clone --depth 1 https://github.com/Lightricks/ComfyUI-LTXVideo && \
    echo "Group 1 done"

RUN cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-Florence2 && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack && \
    git clone --depth 1 https://github.com/vantagewithai/Vantage-HunyuanFoley && \
    git clone --depth 1 https://github.com/kael558/ComfyUI-GGUF-FantasyTalking && \
    echo "Group 2 done"

RUN cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF && \
    git clone --depth 1 https://github.com/Starnodes2024/ComfyUI_StarNodes && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus && \
    git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy && \
    echo "Group 3 done"

RUN cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/jags111/efficiency-nodes-comfyui && \
    git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials && \
    git clone --depth 1 https://github.com/WASasquatch/was-node-suite-comfyui && \
    git clone --depth 1 https://github.com/TemryL/ComfyS3 && \
    echo "Group 4 done"

RUN cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI && \
    git clone --depth 1 https://github.com/1038lab/ComfyUI-QwenVL && \
    git clone --depth 1 https://github.com/thedyze/save-image-extended-comfyui && \
    git clone --depth 1 https://github.com/aining2022/ComfyUI_Swwan && \
    echo "Group 5 done"

# Install Python requirements for all nodes in one pass
RUN find /comfyui/custom_nodes -name "requirements.txt" | \
    xargs -I {} pip install -r {} --no-cache-dir -q && \
    echo "All requirements installed"

# Copy scripts
COPY start.sh /start.sh
COPY download_models.sh /download_models.sh
RUN chmod +x /start.sh /download_models.sh

CMD ["/start.sh"]
