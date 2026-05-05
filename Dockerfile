FROM vastai/comfy:latest

# Everything else stays the same
RUN cd /comfyui/custom_nodes && \
  git clone https://github.com/kijai/ComfyUI-WanVideoWrapper && \
  git clone https://github.com/kijai/ComfyUI-LTXVideo && \
  git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack && \
  git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus && \
  git clone https://github.com/rgthree/rgthree-comfy && \
  git clone https://github.com/WASasquatch/was-node-suite-comfyui && \
  git clone https://github.com/Fannovel16/comfyui_controlnet_aux && \
  git clone https://github.com/jags111/efficiency-nodes-comfyui && \
  git clone https://github.com/cubiq/ComfyUI_essentials && \
  git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts

RUN find /comfyui/custom_nodes -name "requirements.txt" | \
  xargs -I {} pip install -r {} --no-cache-dir

COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml
