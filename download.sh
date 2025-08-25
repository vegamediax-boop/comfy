#!/usr/bin/env bash
set -e

# Base directory—change if needed
MODELS_DIR="${HOME}/ComfyUI/models"

# Ensure all subfolders exist
mkdir -p "${MODELS_DIR}"/{diffusion_models,clip,vae,loras}

echo "Downloading WAN2.2 I2V models..."

# Helper function
download() {
  local url="$1"
  local dest="$2"
  if [[ -s "$dest" ]]; then
    echo "[skip] Already exists: $(basename "$dest")"
  else
    echo "[down] $(basename "$dest")"
    curl -L "$url" -o "$dest"
  fi
}

# GGUF files
download \
  "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf" \
  "$MODELS_DIR/diffusion_models/Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf"

download \
  "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf" \
  "$MODELS_DIR/diffusion_models/Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf"

# LoRA files
download \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" \
  "$MODELS_DIR/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors"

download \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" \
  "$MODELS_DIR/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"

# Text encoder (clip)
download \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "$MODELS_DIR/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# VAE
download \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
  "$MODELS_DIR/vae/wan_2.1_vae.safetensors"

echo "Done! All files are in place."
