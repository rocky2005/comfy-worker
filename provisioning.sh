#!binbash

set -euo pipefail

### Configuration ###
WORKSPACE_DIR=${WORKSPACE-workspace}
COMFYUI_DIR=${WORKSPACE_DIR}ComfyUI
MODELS_DIR=${COMFYUI_DIR}models
INPUTS_DIR=${COMFYUI_DIR}input
WORKFLOWS_DIR=${COMFYUI_DIR}userdefaultworkflows
HF_SEMAPHORE_DIR=${WORKSPACE_DIR}hf_download_sem_$$
HF_MAX_PARALLEL=3
WGET_MAX_PARALLEL=5
MODEL_LOG=${MODEL_LOG-varlogportalcomfyui.log}

# Add your HuggingFace model downloads here later
# Format httpshuggingface.coREPOresolvemainFILE.safetensorsworkspaceComfyUImodelscheckpointsFILE.safetensors
HF_MODELS=(
)

WGET_DOWNLOADS=(
)

### End Configuration ###

mkdir -p $(dirname $MODEL_LOG)

log() {
    local message=[$(date '+%Y-%m-%d %H%M%S')] $1
    echo $message  tee -a $MODEL_LOG
}

script_cleanup() {
    log Cleaning up...
    rm -rf $HF_SEMAPHORE_DIR
    find $MODELS_DIR -name .lock -type f -mmin +60 -delete 2devnull  true
}

script_error() {
    local exit_code=$
    local line_number=$1
    log [ERROR] Provisioning failed at line $line_number with exit code $exit_code
    exit $exit_code
}

trap script_cleanup EXIT
trap 'script_error $LINENO' ERR

install_custom_nodes() {
    log Installing custom nodes...
    
    local nodes_dir=${COMFYUI_DIR}custom_nodes
    mkdir -p $nodes_dir
    cd $nodes_dir

    # Activate venv
    if [ -f venvmainbinactivate ]; then
        . venvmainbinactivate
    fi

    # Install nodes — add more here as you add workflows
    local nodes=(
        httpsgithub.comkijaiComfyUI-WanVideoWrapper
        httpsgithub.comkijaiComfyUI-LTXVideo
        httpsgithub.comltdrdataComfyUI-Impact-Pack
        httpsgithub.comcubiqComfyUI_IPAdapter_plus
        httpsgithub.comrgthreergthree-comfy
        httpsgithub.comWASasquatchwas-node-suite-comfyui
        httpsgithub.comFannovel16comfyui_controlnet_aux
        httpsgithub.comjags111efficiency-nodes-comfyui
        httpsgithub.comcubiqComfyUI_essentials
        httpsgithub.compythongosssssComfyUI-Custom-Scripts
    )

    for node_url in ${nodes[@]}; do
        local node_name
        node_name=$(basename $node_url)
        
        if [ -d $node_name ]; then
            log Node already installed $node_name — skipping
        else
            log Installing $node_name
            git clone $node_url $node_name
        fi

        # Install requirements if they exist
        if [ -f $node_namerequirements.txt ]; then
            pip install -r $node_namerequirements.txt --no-cache-dir -q
        fi
    done

    log ✓ Custom nodes installed
}

set_cleanup_job() {
    local script_dir=optinstance-toolsbin
    local script_path=${script_dir}clean-output.sh
    mkdir -p $script_dir
    
    if [[ ! -f $script_path ]]; then
        cat  $script_path  'CLEAN_OUTPUT'
#!binbash
output_dir=${WORKSPACE-workspace}ComfyUIoutput
min_free_mb=512
available_space=$(df -m ${output_dir}  awk 'NR==2 {print $4}')
if [[ $available_space -lt $min_free_mb ]]; then
    oldest=$(find ${output_dir} -mindepth 1 -type f -printf %T@n 2devnull  sort -n  head -1  awk '{printf %.0f, $1}')
    if [[ -n $oldest ]]; then
        cutoff=$(awk BEGIN {printf %.0f, ${oldest}+86400})
        find ${output_dir} -mindepth 1 -type f ! -newermt @${cutoff} -delete
        find ${output_dir} -mindepth 1 -xtype l -delete
        find ${output_dir} -mindepth 1 -type d -empty -delete
    fi
fi
CLEAN_OUTPUT
        chmod +x $script_path
    fi

    local cron_exists=0
    if crontab -l 2devnull  grep -qF 'clean-output.sh'; then
        cron_exists=1
    fi
    if [[ $cron_exists -eq 0 ]]; then
        (crontab -l 2devnull  true; echo 10     ${script_path})  crontab -
    fi
}

main() {
    log Starting provisioning...

    if [ -f venvmainbinactivate ]; then
        . venvmainbinactivate
    fi

    rm -rf $HF_SEMAPHORE_DIR
    mkdir -p $HF_SEMAPHORE_DIR
    mkdir -p $WORKFLOWS_DIR $INPUTS_DIR
    mkdir -p $MODELS_DIR{checkpoints,text_encoders,loras,vae,diffusion_models,controlnet,unet}

    # Install custom nodes first
    install_custom_nodes

    # Set up cleanup cron
    set_cleanup_job

    log ✓ Provisioning complete
}

main