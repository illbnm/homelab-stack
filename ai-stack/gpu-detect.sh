ARCH=$(uname -m)
if command -v nvidia-smi &>/dev/null; then
    GPU='NVIDIA CUDA'
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null)
elif command -v rocminfo &>/dev/null; then
    GPU='AMD ROCm'
else
    GPU='CPU-only'
fi
echo "Arch: $ARCH | GPU: ${GPU:-CPU-only}"
echo "GPU=${GPU:-CPU-only}" > .env
