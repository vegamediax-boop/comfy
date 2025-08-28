#!/bin/bash
set -e

ROOT="/workspace/ComfyUI"

# Create directory structure
mkdir -p $ROOT/models/diffusion_models
mkdir -p $ROOT/models/text_encoders
mkdir -p $ROOT/models/vae
mkdir -p $ROOT/models/loras
mkdir -p $ROOT/custom_nodes

echo "⬇️ Downloading WAN 2.2 models..."
# WAN 2.2 Repackaged + GGUF
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/model.safetensors
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/QuantStack/Wan2.2-TI2V-5B-GGUF/resolve/main/model.gguf
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/QuantStack/Wan2.2-T2V-A14B-GGUF/resolve/main/model.gguf
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/model.gguf

# WAN 2.2 Text Encoders
wget -nc -P $ROOT/models/text_encoders https://huggingface.co/city96/umt5-xxl-encoder-gguf/resolve/main/umt5-xxl-encoder.gguf
wget -nc -P $ROOT/models/text_encoders https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

# WAN 2.2 Loras
wget -nc -P $ROOT/models/loras https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v.safetensors
wget -nc -P $ROOT/models/loras https://huggingface.co/RaphaelLiu/PusaV1/resolve/main/pusa_v1.safetensors


echo "⬇️ Downloading Flux Kontext..."
# Flux Kontext models
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF/resolve/main/model.gguf
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors

# Flux Kontext text encoders
wget -nc -P $ROOT/models/text_encoders https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors
wget -nc -P $ROOT/models/text_encoders https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors

# Flux Kontext VAE
wget -nc -P $ROOT/models/vae https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors


echo "⬇️ Downloading Flux Krea..."
# Flux Krea models
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/QuantStack/FLUX.1-Krea-dev-GGUF/resolve/main/model.gguf
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/Comfy-Org/FLUX.1-Krea-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-krea-dev_fp8_scaled.safetensors

# Flux Krea VAE
wget -nc -P $ROOT/models/vae https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors


echo "⬇️ Downloading MM-Audio..."
# MM-Audio models
wget -nc -P $ROOT/models/diffusion_models https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/mm_audio_model.safetensors

# MM-Audio Node (git clone)
if [ ! -d "$ROOT/custom_nodes/ComfyUI-MMAudio" ]; then
  git clone https://github.com/kijai/ComfyUI-MMAudio $ROOT/custom_nodes/ComfyUI-MMAudio
fi


echo "✅ All downloads complete. Files placed in $ROOT"
