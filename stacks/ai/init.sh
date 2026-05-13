#!/bin/bash

# Auto-detect GPU hardware and configure Docker runtime accordingly

echo "=== AI Stack GPU Detection ==="

if command -v nvidia-smi &>/dev/null; then
  echo "NVIDIA GPU detected"
  if nvidia-smi &>/dev/null; then
    echo "GPU_SUPPORTED=true"
    export GPU_SUPPORTED=true
    export DOCKER_RUNTIME=nvidia
    echo "DOCKER_RUNTIME=nvidia"
  else
    echo "NVIDIA binary found but driver not responding"
    export GPU_SUPPORTED=false
  fi
elif command -v rocm-smi &>/dev/null; then
  echo "AMD ROCm GPU detected"
  if rocm-smi &>/dev/null; then
    echo "GPU_SUPPORTED=true"
    export GPU_SUPPORTED=true
    export DOCKER_RUNTIME=rocm
    echo "DOCKER_RUNTIME=rocm"
  else
    echo "ROCm binary found but driver not responding"
    export GPU_SUPPORTED=false
  fi
else
  echo "Neither nvidia-smi nor rocm-smi found"
  echo "GPU_SUPPORTED=false"
  export GPU_SUPPORTED=false
fi

if [ "$GPU_SUPPORTED" = true ]; then
  echo "GPU is supported. Docker runtime set to: $DOCKER_RUNTIME"
else
  echo "No GPU support detected. Containers will run on CPU."
fi

echo "=== Environment Variables ==="
echo "GPU_SUPPORTED=$GPU_SUPPORTED"
[ -n "$DOCKER_RUNTIME" ] && echo "DOCKER_RUNTIME=$DOCKER_RUNTIME"
