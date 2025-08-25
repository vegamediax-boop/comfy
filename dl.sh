#!/usr/bin/env bash
# WAN/T2V/I2V installer + migrator for /workspace/ComfyUI (moves files; no symlinks)
set -euo pipefail

# ----- Fixed Comfy root -----
COMFY_ROOT="/workspace/ComfyUI"
MODELS_DIR="$COMFY_ROOT/models"
echo "[info] Using COMFY_ROOT=$COMFY_ROOT"

mkdir -p "$MODELS_DIR"/{diffusion_models,loras,text_encoders,vae,upscale_models}

say(){ printf "%s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing command: $1"; exit 1; }; }
need curl

clean_size(){ printf "%s" "${1//[^0-9]/}"; }
remote_size(){ local u="$1" sz; set +e; sz="$(curl -sSIL "$u" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' | tail -n1)"; set -e; clean_size "$sz"; }

smart_download(){
  # smart_download <url> <subfolder> [filename]
  local url="$1" sub="$2" fname="${3:-$(basename "${url%%\?*}")}"
  local dest="$MODELS_DIR/$sub/$fname"; mkdir -p "$MODELS_DIR/$sub"
  local rsz have status; rsz="$(remote_size "$url" || true)"
  have=0; [[ -f "$dest" ]] && have="$(wc -c <"$dest" 2>/dev/null || echo 0)"
  if [[ -n "$rsz" && "$have" =~ ^[0-9]+$ && "$have" == "$rsz" ]]; then say "[skip] $sub/$fname"; return 0; fi
  set +e
  if [[ -n "$rsz" && "$have" =~ ^[0-9]+$ && "$have" -gt 0 && "$have" -lt "$rsz" ]]; then
    say "[resm] $sub/$fname ($have/$rsz)"; curl -L --fail -C - "$url" -o "$dest"; status=$?
  else
    say "[down] $sub/$fname"; curl -L --fail "$url" -o "$dest"; status=$?
  fi
  set -e
  [[ $status -ne 0 ]] && { say "[FAIL] $url"; return 22; }
}

download_with_fallbacks(){
  # download_with_fallbacks <subfolder> <label> <url1> [url2] ...
  local sub="$1"; shift; local label="$1"; shift; local ok=0
  for u in "$@"; do if smart_download "$u" "$sub" "$label"; then ok=1; break; fi; done
  if [[ $ok -eq 1 ]]; then say "[OK]  $sub/$label"; return 0; fi
  say "[FAIL] All mirrors failed for: $label"
  return 1
}

# ===== 1) MIGRATE (MOVE) anything already downloaded into the correct folders =====
echo "== Moving any pre-downloaded files into $MODELS_DIR =="

# From legacy /ComfyUI path (old scripts)
if [[ -d /ComfyUI/models ]]; then
  # WAN T2V UNets (were under /ComfyUI/models/unet)
  if ls /ComfyUI/models/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors >/dev/null 2>&1; then
    mv -v /ComfyUI/models/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors "$MODELS_DIR/diffusion_models/" || true
  fi
  # Other categories
  for sub in diffusion_models loras text_encoders vae upscale_models; do
    [[ -d "/ComfyUI/models/$sub" ]] || continue
    shopt -s nullglob
    for f in /ComfyUI/models/$sub/*; do mv -v "$f" "$MODELS_DIR/$sub/" || true; done
    shopt -u nullglob
  done
fi

# From /workspaces/ComfyUI (typo’d path) if it exists
if [[ -d /workspaces/ComfyUI/models ]]; then
  # wrong-place UNets
  if ls /workspaces/ComfyUI/models/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors >/dev/null 2>&1; then
    mv -v /workspaces/ComfyUI/models/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors "$MODELS_DIR/diffusion_models/" || true
  fi
  for sub in diffusion_models loras text_encoders vae upscale_models; do
    [[ -d "/workspaces/ComfyUI/models/$sub" ]] || continue
    shopt -s nullglob
    for f in /workspaces/ComfyUI/models/$sub/*; do
      base="$(basename "$f")"
      [[ -e "$MODELS_DIR/$sub/$base" ]] || mv -v "$f" "$MODELS_DIR/$sub/" || true
    done
    shopt -u nullglob
  done
fi

# If someone put UNets under models/unet in the correct root, move them.
if [[ -d "$MODELS_DIR/unet" ]]; then
  if ls "$MODELS_DIR"/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors >/dev/null 2>&1; then
    mv -v "$MODELS_DIR"/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors "$MODELS_DIR/diffusion_models/" || true
  fi
fi

# Clean up broken symlinks if any
find "$MODELS_DIR" -xtype l -exec rm -f {} \; 2>/dev/null || true

# ===== 2) DOWNLOAD anything missing (correct subfolders for your workflow) =====
echo "== Downloading / verifying models =="

# Core WAN files
download_with_fallbacks "vae" "wan_2.1_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" || true

download_with_fallbacks "text_encoders" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" || true

# UNets (must be in diffusion_models)
download_with_fallbacks "diffusion_models" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" || true

download_with_fallbacks "diffusion_models" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" || true

# LoRAs (stable + your FusionX URL)
download_with_fallbacks "loras" "Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" || true

download_with_fallbacks "loras" "Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" || true

download_with_fallbacks "loras" "Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-Lightning_T2V-v1.1-A14B-4steps-lora_LOW_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22-Lightning/Wan2.2-Lightning_T2V_v1.1_A14B_4steps_lora_LOW_fp16.safetensors" || true

download_with_fallbacks "loras" "Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/FusionX_LoRa/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan%20LORAs/FusionX/Wan2.1_T2V_14B_FusionX_LoRA.safetensors" || true

# Upscaler (multi mirrors incl. your mirror)
download_with_fallbacks "upscale_models" "4x-UltraSharp.pth" \
  "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth" \
  "https://huggingface.co/ClarityIO/4x-UltraSharp/resolve/main/4x-UltraSharp.pth" \
  "https://huggingface.co/KohakuBlueleaf/4x-UltraSharp/resolve/main/4x-UltraSharp.pth" \
  "https://huggingface.co/madriss/chkpts/resolve/d9ae35349b0cb67e06aebbeb94316827bcd6be4a/ComfyUI/models/upscale_models/4x-UltraSharp.pth" || true

# Fix ownership/permissions
chown -R "$(id -u)":"$(id -g)" "$MODELS_DIR" || true
chmod -R u+rwX,go+rX "$MODELS_DIR" || true

echo
echo "== Installed model inventory =="
find "$MODELS_DIR" -maxdepth 2 -type f -printf "%h/%f\t%k KB\n" | sort
du -h --max-depth=1 "$MODELS_DIR" | sort -h

echo
echo "== Done. In the UI: Manager → Rescan Models, or restart: =="
echo "cd $COMFY_ROOT && python main.py"
