#!/usr/bin/env bash
# WAN/T2V/I2V model installer for /workspaces/ComfyUI
# - size checks + resume
# - mirror fallbacks
# - optional migration from /ComfyUI -> /workspaces/ComfyUI

set -euo pipefail

COMFY_ROOT="/workspaces/ComfyUI"
MODELS_DIR="$COMFY_ROOT/models"

say(){ printf "%s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing command: $1"; exit 1; }; }
need curl

mkdir -p "$MODELS_DIR"/{diffusion_models,loras,text_encoders,vae,upscale_models}

# ---------- optional migration from /ComfyUI ----------
if [[ -d "/ComfyUI/models" && "/ComfyUI" != "$COMFY_ROOT" ]]; then
  say "== Migrating any models from /ComfyUI -> $MODELS_DIR =="
  shopt -s nullglob
  for sub in diffusion_models loras text_encoders vae upscale_models unet; do
    src="/ComfyUI/models/$sub"
    [[ -d "$src" ]] || continue
    # create target subdir (map 'unet' to diffusion_models for WAN T2V)
    tgt="$MODELS_DIR/$sub"
    [[ "$sub" == "unet" ]] && tgt="$MODELS_DIR/diffusion_models"
    mkdir -p "$tgt"
    for f in "$src"/*; do
      base="$(basename "$f")"
      if [[ ! -e "$tgt/$base" ]]; then
        # put a symlink (fast, saves space). Change to 'mv' to move instead.
        ln -sf "$f" "$tgt/$base"
        say "[link] $tgt/$base -> $f"
      fi
    done
  done
  shopt -u nullglob
fi

# ---------- helpers ----------
clean_size(){ printf "%s" "${1//[^0-9]/}"; }

remote_size(){
  local url="$1" sz
  set +e
  sz="$(curl -sSIL "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' | tail -n1)"
  set -e
  clean_size "$sz"
}

verify_or_prompt(){
  local dest="$1" expect="$2"
  [[ -z "$expect" ]] && return 0
  local have; have="$(wc -c <"$dest" 2>/dev/null || echo 0)"
  [[ "$have" == "$expect" ]] && return 0

  say "[WARN] size mismatch:"
  say "       $dest"
  say "       got:  $have bytes"
  say "       want: $expect bytes"
  local choice
  while true; do
    read -rp "Continue anyway (c), redownload (r), or abort (a)? [c/r/a]: " choice
    case "${choice,,}" in
      r) return 10 ;;
      a) return 11 ;;
      c|"") return 0 ;;
    esac
  done
}

smart_download(){
  # usage: smart_download <url> <subfolder> [filename]
  local url="$1" sub="$2"
  local fname="${3:-$(basename "${url%%\?*}")}"
  local dest_dir="$MODELS_DIR/$sub"
  local dest="$dest_dir/$fname"
  mkdir -p "$dest_dir"

  local rsz have status
  rsz="$(remote_size "$url" || true)"
  have=0; [[ -f "$dest" ]] && have="$(wc -c <"$dest" 2>/dev/null || echo 0)"

  if [[ -n "$rsz" && "$have" =~ ^[0-9]+$ && "$have" == "$rsz" ]]; then
    say "[skip] $sub/$fname (complete)"
    return 0
  fi

  set +e
  if [[ -n "$rsz" && "$have" =~ ^[0-9]+$ && "$have" -gt 0 && "$have" -lt "$rsz" ]]; then
    say "[resm] $sub/$fname ($have/$rsz)"
    curl -L --fail -C - "$url" -o "$dest"; status=$?
  else
    say "[down] $sub/$fname"
    curl -L --fail "$url" -o "$dest"; status=$?
  fi
  set -e

  if [[ $status -ne 0 ]]; then
    say "[FAIL] $url"
    return 22
  fi

  if [[ -n "$rsz" ]]; then
    local decision
    verify_or_prompt "$dest" "$rsz" || decision=$?
    if [[ "${decision:-0}" -eq 10 ]]; then
      rm -f "$dest"
      set +e
      curl -L --fail "$url" -o "$dest"; status=$?
      set -e
      if [[ $status -ne 0 ]]; then return 22; fi
      verify_or_prompt "$dest" "$rsz" || true
    elif [[ "${decision:-0}" -eq 11 ]]; then
      say "Aborting."; exit 1
    fi
  fi
}

download_with_fallbacks(){
  # usage: download_with_fallbacks <subfolder> <label> <url1> [url2]...
  local sub="$1"; shift
  local label="$1"; shift
  local urls=("$@")
  local ok=0

  for u in "${urls[@]}"; do
    if smart_download "$u" "$sub" "$label"; then ok=1; break; fi
  done

  if [[ "$ok" -eq 1 ]]; then
    say "[OK]  $sub/$label"
    return 0
  fi

  say "[FAIL] All mirrors failed for: $label"
  while true; do
    read -rp "Paste a working URL (enter to skip, 'a' to abort): " custom
    if [[ -z "$custom" ]]; then
      say "[SKIP] $sub/$label (no working URL supplied)"
      return 1
    fi
    if [[ "$custom" == "a" ]]; then
      say "Aborting."; exit 1
    fi
    if smart_download "$custom" "$sub" "$label"; then
      say "[OK]  $sub/$label (custom URL)"
      return 0
    else
      say "[warn] custom URL failed; try again."
    fi
  done
}

say "== Installing WAN/T2V/I2V assets into: $MODELS_DIR =="

# -------- Core WAN files --------
download_with_fallbacks "vae" "wan_2.1_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

download_with_fallbacks "text_encoders" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# -------- UNets (your workflow expects them in diffusion_models) --------
download_with_fallbacks "diffusion_models" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"

download_with_fallbacks "diffusion_models" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

# -------- LoRAs (stable + your working FusionX URL) --------
download_with_fallbacks "loras" "Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors"

download_with_fallbacks "loras" "Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"

download_with_fallbacks "loras" "Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V_v1.1_A14B_4steps_lora_LOW_fp16.safetensors"

download_with_fallbacks "loras" "Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/FusionX_LoRa/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/FusionX/Wan2.1_T2V_14B_FusionX_LoRA.safetensors"

# -------- Upscaler (multiple mirrors incl. your folder mirror) --------
download_with_fallbacks "upscale_models" "4x-UltraSharp.pth" \
  "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" \
  "https://huggingface.co/ClarityIO/4x-UltraSharp/resolve/main/4x-UltraSharp.pth" \
  "https://huggingface.co/KohakuBlueleaf/4x-UltraSharp/resolve/main/4x-UltraSharp.pth" \
  "https://huggingface.co/madriss/chkpts/resolve/d9ae35349b0cb67e06aebbeb94316827bcd6be4a/ComfyUI/models/upscale_models/4x-UltraSharp.pth"

# ---------- Inventory ----------
echo
echo "== Installed model inventory =="
find "$MODELS_DIR" -maxdepth 2 -type f -printf "%h/%f\t%k KB\n" | sort
du -h --max-depth=1 "$MODELS_DIR" | sort -h

echo
echo "== Done. If the UI is open, click Manager → Rescan Models, or restart ComfyUI. =="
