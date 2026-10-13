#!/bin/bash

# This script generates docker-compose.override.yml based on GPU_VENDOR and GPU_COUNT.
# It should be run before 'docker compose up'.

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# Default to CPU if not set
GPU_VENDOR=${GPU_VENDOR:-cpu}
GPU_COUNT=${GPU_COUNT:-0}

echo "--- AI Stack Setup ---"
echo "GPU_VENDOR: $GPU_VENDOR"
echo "GPU_COUNT: $GPU_COUNT"

OVERRIDE_FILE="docker-compose.override.yml"

# Start with a clean override file
echo "version: '3.8'" > "$OVERRIDE_FILE"
echo "" >> "$OVERRIDE_FILE"
echo "services:" >> "$OVERRIDE_FILE"

if [ "$GPU_VENDOR" == "nvidia" ]; then
    echo "Configuring for NVIDIA GPU(s)..."
    echo "  ollama:" >> "$OVERRIDE_FILE"
    echo "    deploy:" >> "$OVERRIDE_FILE"
    echo "      resources:" >> "$OVERRIDE_FILE"
    echo "        reservations:" >> "$OVERRIDE_FILE"
    echo "          devices:" >> "$OVERRIDE_FILE"
    echo "            - driver: nvidia" >> "$OVERRIDE_FILE"
    echo "              count: $GPU_COUNT" >> "$OVERRIDE_FILE"
    echo "              capabilities: [gpu]" >> "$OVERRIDE_FILE"
    echo "  stable-diffusion:" >> "$OVERRIDE_FILE"
    echo "    deploy:" >> "$OVERRIDE_FILE"
    echo "      resources:" >> "$OVERRIDE_FILE"
    echo "        reservations:" >> "$OVERRIDE_FILE"
    echo "          devices:" >> "$OVERRIDE_FILE"
    echo "            - driver: nvidia" >> "$OVERRIDE_FILE"
    echo "              count: $GPU_COUNT" >> "$OVERRIDE_FILE"
    echo "              capabilities: [gpu]" >> "$OVERRIDE_FILE"
    # Add NVIDIA specific environment variables if needed by the image
    # For universonic/stable-diffusion-webui, NVIDIA_VISIBLE_DEVICES=all is often sufficient
    # and can be set in the base docker-compose.yml or here.
    # The base docker-compose.yml already has NVIDIA_VISIBLE_DEVICES: all
elif [ "$GPU_VENDOR" == "amd" ]; then
    echo "Configuring for AMD GPU(s) (ROCm)..."
    echo "  ollama:" >> "$OVERRIDE_FILE"
    echo "    deploy:" >> "$OVERRIDE_FILE"
    echo "      resources:" >> "$OVERRIDE_FILE"
    echo "        reservations:" >> "$OVERRIDE_FILE"
    echo "          devices:" >> "$OVERRIDE_FILE"
    echo "            - driver: amd" >> "$OVERRIDE_FILE" # Docker's generic 'amd' driver
    echo "              count: $GPU_COUNT" >> "$OVERRIDE_FILE"
    echo "              capabilities: [gpu,rocm]" >> "$OVERRIDE_FILE" # Explicit ROCm capability
    echo "  stable-diffusion:" >> "$OVERRIDE_FILE"
    echo "    deploy:" >> "$OVERRIDE_FILE"
    echo "      resources:" >> "$OVERRIDE_FILE"
    echo "        reservations:" >> "$OVERRIDE_FILE"
    echo "          devices:" >> "$OVERRIDE_FILE"
    echo "            - driver: amd" >> "$OVERRIDE_FILE"
    echo "              count: $GPU_COUNT" >> "$OVERRIDE_FILE"
    echo "              capabilities: [gpu,rocm]" >> "$OVERRIDE_FILE"
    # For AMD, you might need to pass specific environment variables for ROCm,
    # depending on the image. The 'universonic' image often tries to auto-detect.
    # Example:
    # echo "    environment:" >> "$OVERRIDE_FILE"
    # echo "      - HSA_OVERRIDE_GFX_VERSION=10.3.0" >> "$OVERRIDE_FILE" # Adjust for your specific AMD GPU
elif [ "$GPU_VENDOR" == "cpu" ]; then
    echo "Configuring for CPU-only deployment. No GPU resources will be allocated."
    # No deploy section needed for CPU-only, so the override file will be minimal for these services.
    # We still need to ensure the services are defined, but without the deploy.resources part.
    # The base docker-compose.yml already defines them.
else
    echo "Invalid GPU_VENDOR: $GPU_VENDOR. Please use 'nvidia', 'amd', or 'cpu'."
    echo "Falling back to CPU-only deployment."
    # No deploy section needed.
fi

echo "Generated $OVERRIDE_FILE"
echo "To deploy, run: docker compose -f docker-compose.yml -f docker-compose.override.yml up -d"
echo "Or simply: docker compose up -d (if docker-compose.override.yml is automatically picked up)"
