#!/usr/bin/env bash
set -euo pipefail

COMFY_HOME="/ComfyUI"
MODELS_DIR="$COMFY_HOME/models"
CUSTOM_DIR="$COMFY_HOME/custom_nodes"

say(){ printf "%s\n" "$*"; }

# --- remote size ---
remote_size() {
  curl -sSIL "$1" | awk 'tolower($1)=="content-length:"{sz=$2} END{if(sz!="") print sz}'
}

# --- fetch with checks and prompt on mismatch ---
fetch() {
  local url="$1" sub="$2"
  local fname="${3:-$(basename "${url%%\?*}")}"
  local dest="$MODELS_DIR/$sub/$fname"
  mkdir -p "$MODELS_DIR/$sub"

  local rsz="$(remote_size "$url" || true)"
  local lsz=""

  if [[ -f "$dest" ]]; then
    lsz="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ -n "$rsz" && "$lsz" = "$rsz" ]]; then
      say "[skip] $sub/$fname (complete: $lsz bytes)"
      return 0
    fi
    if [[ -n "$rsz" && "$lsz" -gt 0 && "$lsz" -lt "$rsz" ]]; then
      say "[resm] $sub/$fname ($lsz/$rsz)"
      curl -L --fail -C - "$url" -o "$dest"
    else
      say "[down] $sub/$fname"
      curl -L --fail "$url" -o "$dest"
    fi
  else
    say "[down] $sub/$fname"
    curl -L --fail "$url" -o "$dest"
  fi

  # verify size if known
  if [[ -n "$rsz" ]]; then
    lsz="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ "$lsz" != "$rsz" ]]; then
      say "[WARN] size mismatch for $fname (got $lsz, want $rsz)"
      read -p "Continue anyway (c), redownload (r), or abort (a)? [c/r/a]: " choice
      case "$choice" in
        r|R) rm -f "$dest"; fetch "$url" "$sub" "$fname";;
        a|A) say "Aborting."; exit 1;;
        *) say "Continuing with existing file.";;
      esac
    fi
  fi
}

# --- try mirrors ---
fetch_first() {
  local sub="$1"; shift
  for url in "$@"; do
    if curl -sSIL -o /dev/null -w "%{http_code}" "$url" | grep -qE '^(200|302)$'; then
      fetch "$url" "$sub" && return 0
    fi
  done
  say "[ERR] no working mirrors for $sub"
}

say "== Downloading WAN/T2V/I2V assets =="

# Core
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# T2V UNets
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "unet"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"  "unet"

# LoRAs stable
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"  "loras"

# LoRAs flaky
fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2.1_T2V_14B_FusionX_LoRA.safetensors"

fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors"

# Upscaler
fetch "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" "upscale_models"

say "== All downloads attempted =="
say "Check for warnings above. Restart ComfyUI to use models."
