#!/usr/bin/env bash
set -euo pipefail

# === Defaults ===
MODELS_DIR="${COMFY_MODELS_DIR:-$HOME/ComfyUI/models}"
WORKFLOW=""
CURL_OPTS=("-L" "-C" "-")

usage() {
  cat <<EOF
Usage:
  $0 --workflow path/to/workflow.json [--models-dir /path/to/ComfyUI/models]

Notes:
- The script knows the required filenames from your workflow.
- Two URLs are embedded in the workflow and are used automatically.
- Please paste the URLs for the two GGUF UNets and two LoRAs below (URL_MAP).
EOF
  exit 1
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow) WORKFLOW="$2"; shift 2;;
    --models-dir) MODELS_DIR="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

[[ -z "${WORKFLOW}" ]] && { echo "Error: --workflow is required"; usage; }
[[ ! -f "${WORKFLOW}" ]] && { echo "Error: workflow not found: ${WORKFLOW}"; exit 2; }

# --- Ensure folders ---
mkdir -p "${MODELS_DIR}"/{vae,text_encoders,loras,unet,gguf}

# --- URL map (fill in the TODOs) ---
# key = exact filename as it appears in the workflow
# val = "subdir|url"
declare -A URL_MAP=(
  # Embedded in workflow:
  ["wan_2.1_vae.safetensors"]="vae|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
  ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]="text_encoders|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

  # TODO: paste the correct URLs for your setup:
  ["Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf"]="unet|https://<ADD-URL-FOR-HIGHNOISE-GGUF>"
  ["Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf"]="unet|https://<ADD-URL-FOR-LOWNOISE-GGUF>"
  ["Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors"]="loras|https://<ADD-URL-FOR-LORA-HIGH>"
  ["Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"]="loras|https://<ADD-URL-FOR-LORA-LOW>"
)

# --- Extract required filenames from the workflow ---
mapfile -t REQUIRED < <(python3 - <<'PY' "${WORKFLOW}"
import json, sys, re
p=sys.argv[1]
data=json.load(open(p,encoding="utf-8"))
names=set()
def walk(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if isinstance(v,str) and re.search(r'\.(safetensors|ckpt|pt|pth|gguf|bin)$', v, re.I):
                names.add(v.strip())
            walk(v)
    elif isinstance(o,list):
        for it in o: walk(it)
walk(data)
for n in sorted(names): print(n)
PY
)

echo "== Detected model files in workflow =="
for n in "${REQUIRED[@]}"; do echo "  - $n"; done
echo

download() {
  local subdir="$1" url="$2" fname="$3"
  local dest="${MODELS_DIR}/${subdir}/${fname}"
  if [[ -s "$dest" ]]; then
    echo "[skip] $fname already exists in $subdir"
    return 0
  fi
  echo "[get ] $fname -> $subdir"
  mkdir -p "${MODELS_DIR}/${subdir}"
  curl "${CURL_OPTS[@]}" "$url" -o "$dest"
  # Basic sanity: non-empty
  if [[ ! -s "$dest" ]]; then
    echo "[fail] $fname downloaded but empty. Removing."
    rm -f "$dest"; return 1
  fi
  echo "[done] $fname"
}

# --- Perform downloads for detected files ---
FAILED=()
for fname in "${REQUIRED[@]}"; do
  if [[ -n "${URL_MAP[$fname]:-}" ]]; then
    IFS='|' read -r subdir url <<< "${URL_MAP[$fname]}"
    if [[ "$url" == https://<ADD-* ]]; then
      echo "[TODO] URL missing for $fname — add it to URL_MAP in this script."
      FAILED+=("$fname (missing URL)")
      continue
    fi
    if ! download "$subdir" "$url" "$fname"; then
      FAILED+=("$fname")
    fi
  else
    echo "[warn] No URL mapping for: $fname"
    FAILED+=("$fname (no mapping)")
  fi
done

echo
if (( ${#FAILED[@]} )); then
  echo "Some items were not installed:"
  for x in "${FAILED[@]}"; do echo "  - $x"; done
  exit 3
else
  echo "All referenced models are present in ${MODELS_DIR}."
fi
