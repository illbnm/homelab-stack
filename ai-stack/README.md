# AI Stack for Homelab

This directory contains the Docker Compose setup for a local AI inference stack, including:
- **Ollama**: Local LLM inference engine
- **Open WebUI**: Web interface for Ollama
- **Stable Diffusion**: Image generation
- **Perplexica**: AI-powered search engine

## Features

- **GPU Adaptive Deployment**: Supports NVIDIA (CUDA), AMD (ROCm), and CPU-only fallback.
- **Easy Configuration**: Controlled via environment variables.

## Prerequisites

- Docker and Docker Compose installed.
- For GPU support:
    - **NVIDIA**: NVIDIA Container Toolkit installed and configured.
    - **AMD**: ROCm drivers and Docker ROCm runtime configured.

## Setup and Deployment

1.  **Navigate to the `ai-stack` directory:**
    