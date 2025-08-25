#!/usr/bin/env bash
# Simple + robust WAN/T2V/I2V downloader with full-size check + prompts.
set -euo pipefail

COMFY_HOME="/ComfyUI"
MODELS_DIR="$COMFY_HOME/models"

say(){ printf "%s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing command: $1"; exit 1; }; }
need curl

mkdir -p "$MODELS_DIR"/{unet,loras,text_encoders,vae,upscale_models}

# Return clean numeric Content-Length (or empty) — strips CR and non-digits.
remote_size() {
  local url="$1"
  local sz
  sz="$(curl -sSIL "$url" \
        | tr -d '\r' \
        | awk 'tolower($1)=="content-length:"{print $2}' \
        | tail -n1)"
  # keep digits only
  sz="${sz//[^0-9]/}"
  printf "%s" "$sz"
}

# Ask user what to do on mismatch
ask_on_mismatch() {
  local dest="$1" have="$2" want="$3"
  say "[WARN] size mismatch:"
  say "       $dest"
  say "       got:  $have bytes"
  say "       want: $want bytes"
  local choice
  while true; do
    read -rp "Continue (c), resume/redownload (r), or abort (a)? [c/r/a]: " choice
    case "${choice,,}" in
      r) return 10 ;;  # signal: redo
      a) return 11 ;;  # signal: abort
      c|"") return 0 ;;
    esac
  done
}

# Fetch with full-size check and safe resume
fetch() {
  local url="$1" sub="$2"
  local fname="${3:-$(basename "${url%%\?*}")}"
  local dest_dir="$MODELS_DIR/$sub"
  local dest="$dest_dir/$fname"

  mkdir -p "$dest_dir"

  # Get remote size (may be empty if HEAD blocked)
  local rsz have
  rsz="$(remote_size "$url" || true)"

  # Determine local size if file exists
  have=0
  if [[ -f "$dest" ]]; then
    have="$(wc -c <"$dest" 2>/dev/null || echo 0)"
  fi

  # If we know the expected size and already match → skip
  if [[ -n "$rsz" && "$have" =~ ^[0-9]+$ && "$have" == "$rsz" ]]; then
    say "[skip] $sub/$fname (already complete)"
    return 0
  fi

  # Decide resume vs fresh
  if [[ -n "$rsz" && "$have" =~ ^[0-9]+$ && "$have" -gt 0 && "$have" -lt "$rsz" ]]; then
    say "[resm] $sub/$fname ($have/$rsz)"
    curl -L --fail -C - "$url" -o "$dest"
  else
    say "[down] $sub/$fname"
    curl -L --fail "$url" -o "$dest"
  fi

  # Final verification if we know the expected size
  if [[ -n "$rsz" ]]; then
    have="$(wc -c <"$dest" 2>/dev/null || echo 0)"
    if [[ "$have" != "$rsz" ]]; then
      ask_on_mismatch "$dest" "$have" "$rsz" || true
      case $? in
        10) rm -f "$dest"; fetch "$url" "$sub" "$fname" ;;  # redo
        11) say "Aborting."; exit 1 ;;                      # abort
         0) : ;;                                            # continue
      esac
    fi
  fi
}

# Try multiple URLs; take the first that works (with the same verification).
fetch_first() {
  local sub="$1"; shift
  local url
  for url in "$@"; do
    # Some mirrors block HEAD; try anyway.
    if fetch "$url" "$sub"; then return 0; fi
  done
  say "[ERR] all mirrors failed for a file in '$sub'."; return 1
}

say "== Downloading WAN/T2V/I2V assets with full-size checks =="

# Core (from your workflows)
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "text_encoders"

# T2V UNets
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "unet"
fetch "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"  "unet"

# LoRAs (stable)
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "loras"
fetch "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"  "loras"

# LoRAs (occasionally move → try mirrors)
fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2.1_T2V_14B_FusionX_LoRA.safetensors"

fetch_first "loras" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors"

# Upscaler
fetch "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" "upscale_models"

say "== Done. Restart ComfyUI to load the new assets. =="
