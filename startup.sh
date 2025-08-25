#!/usr/bin/env bash
set -euo pipefail

#############################################
# Vast.AI Default ComfyUI provisioning start
#############################################

# Install ComfyUI
cd /workspace
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI

# (Default script does: pip install, setup venv, install requirements, etc.)
# Adjusted for Vast image which already has pytorch etc.
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

#############################################
# Vast.AI Default ComfyUI provisioning end
#############################################


#############################################
# Wan2.2-I2V model bootstrap (extra part)
#############################################

COMFY_DIR="/workspace/ComfyUI"
MODELS_DIR="${COMFY_DIR}/models"
CN_DIR="${COMFY_DIR}/custom_nodes"

mkdir -p \
  "${MODELS_DIR}/unet" \
  "${MODELS_DIR}/loras" \
  "${MODELS_DIR}/vae" \
  "${MODELS_DIR}/text_encoders" \
  "${CN_DIR}"

download () {
  local url="$1" dst="$2"
  if [[ -s "$dst" ]]; then
    echo "[wan22] Exists: $(basename "$dst")"
    return
  fi
  echo "[wan22] Downloading: $(basename "$dst")"
  wget -c --tries=10 --timeout=30 --show-progress -O "$dst.part" "$url"
  mv "$dst.part" "$dst"
}

# UNet Q3 High/Low
download "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf" \
  "${MODELS_DIR}/unet/Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf"

download "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/LowNoise/Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf" \
  "${MODELS_DIR}/unet/Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf"

# LoRAs (Lightning, High/Low)
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" \
  "${MODELS_DIR}/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors"

download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" \
  "${MODELS_DIR}/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"

# VAE
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
  "${MODELS_DIR}/vae/wan_2.1_vae.safetensors"

# Text Encoder
download "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "${MODELS_DIR}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# Custom nodes
if [[ ! -d "${CN_DIR}/ComfyUI-GGUF" ]]; then
  git clone --depth=1 https://github.com/city96/ComfyUI-GGUF "${CN_DIR}/ComfyUI-GGUF" || true
fi
if [[ ! -d "${CN_DIR}/ComfyUI-Manager" ]]; then
  git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager "${CN_DIR}/ComfyUI-Manager" || true
fi

echo "[wan22] Bootstrap complete."
