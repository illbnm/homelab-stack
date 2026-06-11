 ```diff
--- /dev/null
+++ b/stacks/ai/docker-compose.yml
@@ -0,0 +1,168 @@
+version: "3.8"
+
+services:
+  # ============================================
+  # Ollama - LLM Inference Engine
+  # ============================================
+  ollama:
+    image: ollama/ollama:0.3.12
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0
+      - OLLAMA_ORIGINS=*
+      - OLLAMA_MODELS=/root/.ollama/models
+    volumes:
+      - ollama-data:/root/.ollama
+    networks:
+      - ai-network
+    # GPU support: NVIDIA, AMD, or CPU fallback
+    deploy:
+      resources:
+        reservations:
+          devices:
+            - driver: ${GPU_DRIVER:-nvidia}
+              count: all
+              capabilities: [gpu]
+    # Fallback for CPU mode: override with docker-compose.cpu.yml or set GPU_DRIVER=none
+    profiles:
+      - gpu
+
+  ollama-cpu:
+    image: ollama/ollama:0.3.12
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0
+      - OLLAMA_ORIGINS=*
+      - OLLAMA_MODELS=/root/.ollama/models
+    volumes:
+      - ollama-data:/root/.ollama
+    networks:
+      - ai-network
+    profiles:
+      - cpu
+
+  # ============================================
+  # Open WebUI - LLM Web Interface
+  # ============================================
+  open-webui:
+    image: ghcr.io/open-webui/open-webui:0.3.32
+    container_name: open-webui
+    restart: unless-stopped
+    environment:
+      - OLLAMA_BASE_URL=http://ollama:11434
+      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-changeme}
+      - ENABLE_SIGNUP=${ENABLE_SIGNUP:-true}
+      - DEFAULT_MODELS=${DEFAULT_MODELS:-}
+      - DEFAULT_USER_ROLE=${DEFAULT_USER_ROLE:-pending}
+      - ENABLE_RAG_WEB_SEARCH=${ENABLE_RAG_WEB_SEARCH:-false}
+      - RAG_WEB_SEARCH_ENGINE=${RAG_WEB_SEARCH_ENGINE:-duckduckgo}
+      - ENABLE_IMAGE_GENERATION=${ENABLE_IMAGE_GENERATION:-true}
+      - IMAGE_GENERATION_ENGINE=${IMAGE_GENERATION_ENGINE:-automatic1111}
+      - AUTOMATIC1111_BASE_URL=${AUTOMATIC1111_BASE_URL:-http://stable-diffusion:7860}
+    volumes:
+      - open-webui-data:/app/backend/data
+    networks:
+      - ai-network
+      - traefik-network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.open-webui.rule=Host(`${OPEN_WEBUI_DOMAIN:-ai.localhost}`)"
+      - "traefik.http.routers.open-webui.entrypoints=websecure"
+      - "traefik.http.routers.open-webui.tls.certresolver=letsencrypt"
+      - "traefik.http.services.open-webui.loadbalancer.server.port=8080"
+      - "traefik.http.routers.open-webui.middlewares=authentik@docker"
+    depends_on:
+      - ollama
+
+  # ============================================
+  # Stable Diffusion - Image Generation
+  # ============================================
+  stable-diffusion:
+    image: universonic/stable-diffusion-webui:latest-sha
+    container_name: stable-diffusion
+    restart: unless-stopped
+    environment:
+      - CLI_ARGS=--listen --port 7860 --enable-insecure-extension-access --api
+      - NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}
+    volumes:
+      - stable-diffusion-data:/app/stable-diffusion-webui
+      - stable-diffusion-models:/app/stable-diffusion-webui/models
+      - stable-diffusion-outputs:/app/stable-diffusion-webui/outputs
+    networks:
+      - ai-network
+      - traefik-network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.stable-diffusion.rule=Host(`${STABLE_DIFFUSION_DOMAIN:-sd.localhost}`)"
+      - "traefik.http.routers.stable-diffusion.entrypoints=websecure"
+      - "traefik.http.routers.stable-diffusion.tls.certresolver=letsencrypt"
+      - "traefik.http.services.stable-diffusion.loadbalancer.server.port=7860"
+      - "traefik.http.routers.stable-diffusion.middlewares=authentik@docker"
+    # GPU support
+    deploy:
+      resources:
+        reservations:
+          devices:
+            - driver: ${GPU_DRIVER:-nvidia}
+              count: all
+              capabilities: [gpu]
+    profiles:
+      - gpu
+
+  stable-diffusion-cpu:
+    image: universonic/stable-diffusion-webui:latest-sha
+    container_name: stable-diffusion
+    restart: unless-stopped
+    environment:
+      - CLI_ARGS=--listen --port 7860 --enable-insecure-extension-access --api --use-cpu all --no-half
+    volumes:
+      - stable-diffusion-data:/app/stable-diffusion-webui
+      - stable-diffusion-models:/app/stable-diffusion-webui/models
+      - stable-diffusion-outputs:/app/stable-diffusion-webui/outputs
+    networks:
+      - ai-network
+      - traefik-network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.stable-diffusion.rule=Host(`${STABLE_DIFFUSION_DOMAIN:-sd.localhost}`)"
+      - "traefik.http.routers.stable-diffusion.entrypoints=websecure"
+      - "traefik.http.routers.stable-diffusion.tls.certresolver=letsencrypt"
+      - "traefik.http.services.stable-diffusion.loadbalancer.server.port=7860"
+      - "traefik.http.routers.stable-diffusion.middlewares=authentik@docker"
+    profiles:
+      - cpu
+
+# ============================================
+# Networks
+# ============================================
+networks:
+  ai-network:
+    driver: bridge
+  traefik-network:
+    external: true
+
+# ============================================
+# Volumes
+# ============================================
+volumes:
+  ollama-data:
+  open-webui-data:
+  stable-diffusion-data:
+  stable-diffusion