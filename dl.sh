#!/usr/bin/env bash
set -euo pipefail

COMFY_HOME="/ComfyUI"
MODELS_DIR="$COMFY_HOME/models"
CUSTOM_DIR="$COMFY_HOME/custom_nodes"

say(){ printf "%s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing: $1"; exit 1; }; }

need curl; need git; need python3; need pip

# Optional: ffmpeg for mp4 export
if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y ffmpeg || true
  else
    say "[warn] ffmpeg not installed (needed for mp4 export)."
  fi
fi

mkdir -p "$MODELS_DIR"/{unet,loras,text_encoders,vae,upscale_models} "$CUSTOM_DIR"

# --- utility: get remote size, return "" if not available ---
remote_size() {
  curl -sSIL "$1" | awk 'tolower($1)=="content-length:"{sz=$2} END{if(sz!="") printf "%s", sz}'
}

# --- smart fetch: verify size, resume partials ---
fetch() {
  local url="$1"; shift
  local sub="$1"; shift || true
  local fname="${1:-}"; shift || true

  # derive filename safely (strip query string)
  if [[ -z "${fname}" ]]; then
    fname="$(basename "${url%%\?*}")"
  fi

  local dest="$MODELS_DIR/$sub/$fname"
  mkdir -p "$MODELS_DIR/$sub"

  # remote size (may be empty)
  local rsz local_sz
  rsz="$(remote_size "$url" || true)"
  if [[ -f "$dest" ]]; then
    local_sz="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ -n "$rsz" && "$local_sz" == "$rsz" ]]; then
      say "[skip] $sub/$fname (already complete)"
      return 0
    fi
    if [[ -n "$rsz" && "$local_sz" -gt 0 && "$local_sz" -lt "$rsz" ]]; then
      say "[resm] $sub/$fname ($local_sz/$rsz)"
      curl -L --fail -C - "$url" -o "$dest"
    else
      say "[down] $sub/$fname"
      curl -L --fail "$url" -o "$dest"
    fi
  else
    say "[down] $sub/$fname"
    curl -L --fail "$url" -o "$dest"
  fi

  # verify after download if size known
  if [[ -n "$rsz" ]]; then
    local_sz="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ "$local_sz" != "$rsz" ]]; then
      say "[ERR ] size mismatch for $fname (got $local_sz, want $rsz)"; return 1
    fi
  fi
}

# --- try multiple mirrors/paths ---
fetch_first() {
  local sub="$1"; shift
  local tried=0
  for url in "$@"; do
    tried=1
    # preflight; some hosts block HEAD, still try
    if curl -sSIL -o /dev/null -w "%{http_code}" "$url" | grep -qE '^(200|302)$'; then
      fetch "$url" "$sub" && return 0 || true
    else
      fetch "$url" "$sub" && return 0 || true
    fi
  done
  [[ $tried -eq 1 ]] && { say "[ERR ] all mirrors failed for $sub item."; return 1; }
}

say "== Downloading WAN/T2V/I2V assets with size checks =="

# Core
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# T2V UNets (from your workflow)
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "unet"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"  "unet"

# LoRAs (stable)
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"  "loras"

# LoRAs (flaky → mirrors)
fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/FusionX/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2.1_T2V_14B_FusionX_LoRA.safetensors"

fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V_v1.1_A14B_4steps_lora_LOW_fp16.safetensors"

# Upscaler
fetch "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" "upscale_models"

# -------- Custom nodes (for your workflow) --------
git_get() {
  local repo="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    say "[git ] update $(basename "$dest")"; git -C "$dest" pull --ff-only || true
  else
    say "[git ] clone  $(basename "$dest")"; git clone --depth=1 "$repo" "$dest"
  fi
  [[ -f "$dest/requirements.txt" ]] && { say "[pip ] $(basename "$dest")"; pip install -r "$dest/requirements.txt"; }
}

say "== Installing custom nodes =="
git_get "https://github.com/rgthree/rgthree-comfy.git"                 "$CUSTOM_DIR/rgthree-comfy"
git_get "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$CUSTOM_DIR/ComfyUI-VideoHelperSuite"
git_get "https://github.com/Coyote-A/ComfyUI-UltimateSDUpscale.git"   "$CUSTOM_DIR/ComfyUI-UltimateSDUpscale"
git_get "https://github.com/canisminor1990/ComfyUI-Easy-Use.git"      "$CUSTOM_DIR/ComfyUI-Easy-Use"

pip install --upgrade pip
pip install imageio imageio-ffmpeg opencv-python av numpy || true

say "== Done =="
say "Models  → $MODELS_DIR"
say "Nodes   → $CUSTOM_DIR"
say "Restart ComfyUI to load nodes."
