#!/usr/bin/env bash
set -euo pipefail

# -------- Paths --------
COMFY_HOME="/ComfyUI"
MODELS_DIR="$COMFY_HOME/models"
CUSTOM_DIR="$COMFY_HOME/custom_nodes"

# -------- Helpers --------
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }

download() {
  local url="$1" sub="$2" file dest
  file="$(basename "$url")"
  dest="$MODELS_DIR/$sub/$file"
  mkdir -p "$MODELS_DIR/$sub"
  if [[ -s "$dest" ]]; then
    echo "[skip] $sub/$file"
  else
    echo "[down] $sub/$file"
    curl -L --fail "$url" -o "$dest"
  fi
}

clone_or_pull() {
  local repo_url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    echo "[upd ] $(basename "$dest")"
    git -C "$dest" pull --ff-only || true
  else
    echo "[git ] $(basename "$dest")"
    git clone --depth=1 "$repo_url" "$dest"
  fi
  # install python deps if any
  if [[ -f "$dest/requirements.txt" ]]; then
    echo "[pip ] $(basename "$dest") requirements.txt"
    pip install -r "$dest/requirements.txt"
  fi
}

echo "== Checking tools =="
need_cmd curl
need_cmd git
need_cmd python3
need_cmd pip

# ffmpeg is needed by VideoHelperSuite to write mp4s
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[info] ffmpeg not found; attempting apt install (sudo may be required)"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y ffmpeg || echo "[warn] apt install failed; install ffmpeg manually"
  else
    echo "[warn] No apt-get. Please install ffmpeg for video output."
  fi
fi

echo "== Creating model folders =="
mkdir -p "$MODELS_DIR"/{unet,loras,text_encoders,vae,upscale_models}

echo "== Downloading models =="

# --- Core (VAE + text encoder) ---
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# --- T2V UNets (from your T2V workflow JSON) ---
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "unet"
download "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" "unet"

# --- LoRAs referenced in your workflows ---
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" "loras"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" "loras"

# --- Upscaler model used by UltimateSDUpscale ---
download "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" "upscale_models"

echo "== Installing custom nodes (workflow dependencies) =="
mkdir -p "$CUSTOM_DIR"

# Lora Loader Stack (rgthree)
clone_or_pull "https://github.com/rgthree/rgthree-comfy.git" \
              "$CUSTOM_DIR/rgthree-comfy"

# VideoHelperSuite (VHS_VideoCombine)
clone_or_pull "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" \
              "$CUSTOM_DIR/ComfyUI-VideoHelperSuite"

# UltimateSDUpscale
clone_or_pull "https://github.com/Coyote-A/ComfyUI-UltimateSDUpscale.git" \
              "$CUSTOM_DIR/ComfyUI-UltimateSDUpscale"

# Easy-Use (provides 'easy float' etc.)
clone_or_pull "https://github.com/canisminor1990/ComfyUI-Easy-Use.git" \
              "$CUSTOM_DIR/ComfyUI-Easy-Use"

# A few runtime libs commonly needed by the above (safe if already present)
pip install --upgrade pip
pip install imageio imageio-ffmpeg opencv-python av numpy

echo
echo "== Done =="
echo "Models -> $MODELS_DIR"
echo "Custom nodes -> $CUSTOM_DIR"
echo "Restart ComfyUI to load the new nodes."
