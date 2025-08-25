#!/usr/bin/env bash
# WAN/T2V/I2V models + custom nodes installer for /workspace/ComfyUI
# - Moves any pre-downloaded files into /workspace/ComfyUI/models (no symlinks)
# - Downloads missing assets with size checks + resume + mirrors
# - Installs required custom nodes and their Python deps

set -euo pipefail

COMFY_ROOT="/workspace/ComfyUI"
MODELS_DIR="$COMFY_ROOT/models"
CUSTOM_DIR="$COMFY_ROOT/custom_nodes"
echo "[info] Using COMFY_ROOT=$COMFY_ROOT"

mkdir -p "$MODELS_DIR"/{diffusion_models,loras,text_encoders,vae,upscale_models} "$CUSTOM_DIR"

say(){ printf "%s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { say "Missing command: $1"; exit 1; }; }
need curl
need git
need python3
command -v pip >/dev/null 2>&1 || { say "Missing pip (python3 -m pip)"; exit 1; }

# Optional: ffmpeg for VideoHelperSuite exporters
if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y ffmpeg || true
  fi
fi

clean_size(){ printf "%s" "${1//[^0-9]/}"; }
remote_size(){ local u="$1" sz; set +e; sz="$(curl -sSIL "$u" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' | tail -n1)"; set -e; clean_size "$sz"; }

verify_or_prompt(){
  local dest="$1" expect="$2"
  [[ -z "$expect" ]] && return 0
  local have; have="$(wc -c <"$dest" 2>/dev/null || echo 0)"
  [[ "$have" == "$expect" ]] && return 0
  say "[WARN] size mismatch: $dest (got $have, want $expect)"
  local c; while true; do
    read -rp "Continue anyway (c), redownload (r), abort (a)? [c/r/a]: " c
    case "${c,,}" in r) return 10;; a) return 11;; c|"") return 0;; esac
  done
}

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
  if [[ -n "$rsz" ]]; then
    local d=0; verify_or_prompt "$dest" "$rsz" || d=$?
    if [[ $d -eq 10 ]]; then rm -f "$dest"; curl -L --fail "$url" -o "$dest"; verify_or_prompt "$dest" "$rsz" || true
    elif [[ $d -eq 11 ]]; then echo "Aborting."; exit 1; fi
  fi
}

download_with_fallbacks(){
  # download_with_fallbacks <subfolder> <label> <url1> [url2] ...
  local sub="$1"; shift; local label="$1"; shift; local ok=0
  for u in "$@"; do if smart_download "$u" "$sub" "$label"; then ok=1; break; fi; done
  if [[ $ok -eq 1 ]]; then say "[OK]  $sub/$label"; return 0; fi
  say "[FAIL] All mirrors failed for: $label"
  while true; do
    read -rp "Paste a working URL (enter=skip, 'a'=abort): " custom
    [[ -z "$custom" ]] && { say "[SKIP] $sub/$label"; return 1; }
    [[ "$custom" == "a" ]] && { echo "Aborting."; exit 1; }
    if smart_download "$custom" "$sub" "$label"; then say "[OK]  $sub/$label (custom URL)"; return 0; fi
    say "[warn] custom URL failed; try again."
  done
}

git_get(){
  # git_get <repo> <dest>
  local repo="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    say "[git ] update $(basename "$dest")"; git -C "$dest" pull --ff-only || true
  else
    say "[git ] clone  $(basename "$dest")"; git clone --depth=1 "$repo" "$dest"
  fi
  if [[ -f "$dest/requirements.txt" ]]; then
    say "[pip ] install deps for $(basename "$dest")"
    pip install -r "$dest/requirements.txt" || true
  fi
}

# ===== 1) MOVE any pre-downloaded files into the correct folders (no symlinks) =====
say "== Moving any pre-downloaded files into $MODELS_DIR =="

# From legacy /ComfyUI path
if [[ -d /ComfyUI/models ]]; then
  if ls /ComfyUI/models/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors >/dev/null 2>&1; then
    mv -v /ComfyUI/models/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors "$MODELS_DIR/diffusion_models/" || true
  fi
  for sub in diffusion_models loras text_encoders vae upscale_models; do
    [[ -d "/ComfyUI/models/$sub" ]] || continue
    shopt -s nullglob
    for f in /ComfyUI/models/$sub/*; do mv -v "$f" "$MODELS_DIR/$sub/" || true; done
    shopt -u nullglob
  done
fi

# From /workspaces (typo’d older path), if present
if [[ -d /workspaces/ComfyUI/models ]]; then
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

# If someone put UNets under models/unet in the current root, move them
if [[ -d "$MODELS_DIR/unet" ]]; then
  if ls "$MODELS_DIR"/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors >/dev/null 2>&1; then
    mv -v "$MODELS_DIR"/unet/wan2.2_t2v_*_noise_14B_fp8_scaled.safetensors "$MODELS_DIR/diffusion_models/" || true
  fi
fi

# Remove broken symlinks if any
find "$MODELS_DIR" -xtype l -exec rm -f {} \; 2>/dev/null || true

# ===== 2) DOWNLOAD anything missing (into correct folders) =====
say "== Downloading / verifying models =="

# Core WAN files
download_with_fallbacks "vae" "wan_2.1_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" || true

download_with_fallbacks "text_encoders" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" || true

# UNets (your workflow expects in di
