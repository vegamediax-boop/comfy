#!/bin/bash
set -e

ROOT="/workspace/ComfyUI"

# Prompt for HuggingFace token each run
read -sp "Enter your HuggingFace token: " HF_TOKEN
echo ""

# Create required directories
mkdir -p "$ROOT/models/diffusion_models"
mkdir -p "$ROOT/models/text_encoders"
mkdir -p "$ROOT/models/vae"
mkdir -p "$ROOT/models/loras"
mkdir -p "$ROOT/custom_nodes"

# Store updated script lines for go.txt
SCRIPT_LINES=()

download() {
  url="$1"; outdir="$2"
  echo "⬇️ Downloading: $url"
  # Try the download
  if ! wget --header="Authorization: Bearer $HF_TOKEN" -nc -P "$outdir" "$url"; then
    echo "❌ Failed to download: $url"
    read -p "Enter replacement URL: " new_url
    url="$new_url"
    wget --header="Authorization: Bearer $HF_TOKEN" -nc -P "$outdir" "$url"
  fi
  # Record the (possibly updated) line for go.txt
  SCRIPT_LINES+=("download $url \"$outdir\"")
}

# ----------------- WAN 2.2 -----------------
download https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors "$ROOT/models/vae"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_vae.safetensors "$ROOT/models/vae"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_ti2v_5B_fp16.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"

# ----------------- Encoders (chatpig) -----------------
download https://huggingface.co/chatpig/encoder/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/clip_l.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/t5xxl_fp16.safetensors "$ROOT/models/text_encoders"

# ----------------- Loras -----------------
download https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v.safetensors "$ROOT/models/loras"
download https://huggingface.co/RaphaelLiu/PusaV1/resolve/main/pusa_v1.safetensors "$ROOT/models/loras"

# ----------------- Flux Kontext -----------------
download https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF/resolve/main/model.gguf "$ROOT/models/diffusion_models"
download https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors "$ROOT/models/vae"

# ----------------- Flux Krea -----------------
download https://huggingface.co/QuantStack/FLUX.1-Krea-dev-GGUF/resolve/main/model.gguf "$ROOT/models/diffusion_models"
download https://huggingface.co/Comfy-Org/FLUX.1-Krea-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-krea-dev_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors "$ROOT/models/vae"

# ----------------- MM-Audio -----------------
download https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/mm_audio_model.safetensors "$ROOT/models/diffusion_models"

if [ ! -d "$ROOT/custom_nodes/ComfyUI-MMAudio" ]; then
  git clone https://github.com/kijai/ComfyUI-MMAudio "$ROOT/custom_nodes/ComfyUI-MMAudio"
fi

echo "✅ All files downloaded and organized under $ROOT"

# Write out go.txt with updated links
{
  echo '#!/bin/bash'
  echo 'set -e'
  echo ''
  echo 'ROOT="/workspace/ComfyUI"'
  echo ''
  echo 'read -sp "Enter your HuggingFace token: " HF_TOKEN'
  echo 'echo ""'
  echo ''
  echo 'download() {'
  echo '  url="$1"; outdir="$2"'
  echo '  wget --header="Authorization: Bearer $HF_TOKEN" -nc -P "$outdir" "$url"'
  echo '}'
  echo ''
  for line in "${SCRIPT_LINES[@]}"; do
    echo "$line"
  done
} > go.txt

echo "💾 Saved updated script with resolved URLs to go.txt"
