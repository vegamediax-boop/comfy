#!/usr/bin/env bash
set -euo pipefail

COMFY_HOME="/ComfyUI"
MODELS_DIR="$COMFY_HOME/models"
CUSTOM_DIR="$COMFY_HOME/custom_nodes"

# ---------- tiny utils ----------
say(){ printf "%s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing: $1"; exit 1; }; }

need curl; need git; need python3; need pip

# ffmpeg helps VideoHelperSuite write MP4
if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    say "[info] ffmpeg not found → installing via apt-get"; apt-get update && apt-get install -y ffmpeg || true
  else
    say "[warn] ffmpeg not installed (needed for mp4 export)."
  fi
fi

mkdir -p "$MODELS_DIR"/{unet,loras,text_encoders,vae,upscale_models} "$CUSTOM_DIR"

# --- get remote size (bytes) or empty if unknown ---
remote_size(){
  # follow redirects, take the last Content-Length
  curl -sSIL "$1" | awk 'tolower($1)=="content-length:"{cl=$2} END{if(cl!="") printf "%s", cl}'
}

# --- smart downloader: verify full size, resume partials ---
fetch(){
  local url="$1" dest_dir="$2" fname="${3:-$(basename "$url")}"
  local dest="$MODELS_DIR/$dest_dir/$fname"
  mkdir -p "$MODELS_DIR/$dest_dir"

  # Remote size (may be blank for some hosts)
  local rsz local_sz
  rsz="$(remote_size "$url" || true)"
  if [[ -f "$dest" ]]; then
    local_sz="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ -n "$rsz" && "$local_sz" == "$rsz" ]]; then
      say "[skip] $dest_dir/$fname (already full: $local_sz bytes)"
      return 0
    fi
    if [[ -n "$rsz" && "$local_sz" -gt 0 && "$local_sz" -lt "$rsz" ]]; then
      say "[resm] $dest_dir/$fname ($local_sz/$rsz)"; curl -L --fail -C - "$url" -o "$dest"
    else
      say "[down] $dest_dir/$fname"; curl -L --fail "$url" -o "$dest"
    fi
  else
    say "[down] $dest_dir/$fname"; curl -L --fail "$url" -o "$dest"
  fi

  # Final verification if we know the expected size
  if [[ -n "$rsz" ]]; then
    local_sz="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ "$local_sz" != "$rsz" ]]; then
      say "[ERR ] size mismatch for $fname (have $local_sz, want $rsz) — re-run or check mirror."
      return 1
    fi
  fi
}

# Try multiple mirrors/paths; use the first that has a good HEAD or completes the download
fetch_first(){
  local sub="$1"; shift
  local tried=0
  for url in "$@"; do
    tried=1
    # quick preflight: if HEAD gives 200/302 we try it; if HEAD not available still try
    if curl -sSIL -o /dev/null -w "%{http_code}" "$url" | grep -qE '^(200|302)$'; then
      if fetch "$url" "$sub"; then return 0; fi
    else
      # some endpoints hide HEAD; attempt direct fetch
      if fetch "$url" "$sub"; then return 0; fi
    fi
  done
  if [[ "$tried" -eq 1 ]]; then
    say "[ERR ] all mirrors failed for folder '$sub'."
    return 1
  fi
}

say "== Downloading WAN/T2V/I2V assets with size checks =="

# ---- Core VAE + text encoder ----
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# ---- T2V UNets (from your workflow) ----
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "unet"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"  "unet"

# ---- LoRAs (stable) ----
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"  "loras"

# ---- LoRAs (flaky → try mirrors/alt paths) ----
fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/FusionX/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2.1_T2V_14B_FusionX_LoRA.safetensors"

fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V_v1.1_A14B_4steps_lora_LOW_fp16.safetensors"

# ---- Upscaler ----
fetch "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" "upscale_models"

say "== Installing custom nodes =="
git_get(){ # clone or pull and pip-install requirements
  local repo="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    say "[git ] update $(basename "$dest")"; git -C "$dest" pull --ff-only || true
  else
    say "[git ] clone  $(basename "$dest")"; git clone --depth=1 "$repo" "$dest"
  fi
  [[ -f "$dest/requirements.txt" ]] && { say "[pip ] $(basename "$dest")"; pip install -r "$dest/requirements.txt"; }
}

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
