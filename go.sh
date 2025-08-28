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

download() {
  url="$1"; outdir="$2"
  echo "⬇️ Downloading: $url"
  wget --header="Authorization: Bearer $HF_TOKEN" -nc -P "$outdir" "$url"
}

echo "⬇️ Downloading WAN 2.2 models (updated)..."
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/umt5_xxl_fp8_e4m3fn_scaled.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan_2.1_vae.safetensors "$ROOT/models/vae"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_vae.safetensors "$ROOT/models/vae"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_ti2v_5B_fp16.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/ComfyUI_examples/resolve/main/wan22/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors "$ROOT/models/diffusion_models"

echo "⬇️ Downloading chatpig encoders..."
download https://huggingface.co/chatpig/encoder/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/clip_l.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/clip_g.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/t5xl_fp16.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/t5xl_fp32.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/chatpig/encoder/resolve/main/t5xxl-encoder-q8_0.gguf "$ROOT/models/text_encoders"

echo "⬇️ Downloading WAN 2.2 Loras..."
download https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v.safetensors "$ROOT/models/loras"
download https://huggingface.co/RaphaelLiu/PusaV1/resolve/main/pusa_v1.safetensors "$ROOT/models/loras"

echo "⬇️ Downloading Flux Kontext..."
download https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF/resolve/main/model.gguf "$ROOT/models/diffusion_models"
download https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors "$ROOT/models/text_encoders"
download https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors "$ROOT/models/vae"

echo "⬇️ Downloading Flux Krea..."
download https://huggingface.co/QuantStack/FLUX.1-Krea-dev-GGUF/resolve/main/model.gguf "$ROOT/models/diffusion_models"
download https://huggingface.co/Comfy-Org/FLUX.1-Krea-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-krea-dev_fp8_scaled.safetensors "$ROOT/models/diffusion_models"
download https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors "$ROOT/models/vae"

echo "⬇️ Downloading MM-Audio..."
download https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/mm_audio_model.safetensors "$ROOT/models/diffusion_models"

if [ ! -d "$ROOT/custom_nodes/ComfyUI-MMAudio" ]; then
  git clone https://github.com/kijai/ComfyUI-MMAudio "$ROOT/custom_nodes/ComfyUI-MMAudio"
fi

echo "✅ All files downloaded and organized under $ROOT"
