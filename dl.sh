#!/usr/bin/env bash
set -e

BASE="/ComfyUI/models"
mkdir -p "$BASE"/{unet,loras,text_encoders,vae,upscale_models}

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

echo "== WAN 2.2 T2V / I2V Dependencies =="

# --- Core models ---
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# --- T2V High/Low Noise UNets ---
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "unet"
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" "unet"

# --- LoRAs (Speed + Fusion) ---
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" "loras"

# --- Upscaler ---
download "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" "upscale_models"

echo "== All required files downloaded into $BASE =="
