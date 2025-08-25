#!/usr/bin/env bash
set -e

BASE="${HOME}/ComfyUI/models"
mkdir -p "$BASE"/{unet,loras,text_encoders,vae}

download() {
  url=$1; dir=$2; file="${url##*/}"
  dest="$BASE/$dir/$file"
  if [[ -s "$dest" ]]; then
    echo "[skip] $file"
  else
    echo "[down] $file"
    curl -L "$url" -o "$dest"
  fi
}

# Corrected URLs:
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# (Include previously found URLs for GGUF UNets and LoRAs)
download "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf" "unet"
download "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf" "unet"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" "loras"

echo "All files downloaded and placed successfully."
