 ```diff
--- a/stacks/ai/docker-compose.yml
+++ b/stacks/ai/docker-compose.yml
@@ -0,0 +1,150 @@
+services:
+  # ─────────────────────────────────────────────────────────
+  # Ollama — LLM 推理引擎
+  # ─────────────────────────────────────────────────────────
+  ollama:
+    image: ollama/ollama:0.3.12
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0:11434
+      - OLLAMA_ORIGINS=*
+      - OLLAMA_KEEP_ALIVE=24h
+    volumes:
+      - ollama-data:/root/.ollama
+    networks:
+      - ai
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.ollama.rule=Host(`ollama.${DOMAIN}`)"
+      - "traefik.http.routers.ollama.entrypoints=websecure"
+      - "traefik.http.routers.ollama.tls.certresolver=letsencrypt"
+      - "traefik.http.services.ollama.loadbalancer.server.port=11434"
+    deploy:
+      resources:
+        reservations:
+          devices:
+            - driver: nvidia
+              count: all
+              capabilities: [gpu]
+    profiles:
+      - nvidia
+
+  ollama-amd:
+    image: ollama/ollama:0.3.12-rocm
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0:11434
+      - OLLAMA_ORIGINS=*
+      - OLLAMA_KEEP_ALIVE=24h
+      - HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-10.1.0}
+    devices:
+      - /dev/kfd:/dev/kfd
+      - /dev/dri:/dev/dri
+    volumes:
+      - ollama-data:/root/.ollama
+    networks:
+      - ai
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.ollama.rule=Host(`ollama.${DOMAIN}`)"
+      - "traefik.http.routers.ollama.entrypoints=websecure"
+      - "traefik.http.routers.ollama.tls.certresolver=letsencrypt"
+      - "traefik.http.services.ollama.loadbalancer.server.port=11434"
+    profiles:
+      - amd
+
+  ollama-cpu:
+    image: ollama/ollama:0.3.12
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0:11434
+      - OLLAMA_ORIGINS=*
+      - OLLAMA_KEEP_ALIVE=24h
+    volumes:
+      - ollama-data:/root/.ollama
+    networks:
+      - ai
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.ollama.rule=Host(`ollama.${DOMAIN}`)"
+      - "traefik.http.routers.ollama.entrypoints=websecure"
+      - "traefik.http.routers.ollama.tls.certresolver=letsencrypt"
+      - "traefik.http.services.ollama.loadbalancer.server.port=11434"
+    profiles:
+      - cpu
+
+  # ─────────────────────────────────────────────────────────
+  # Open WebUI — LLM Web 界面
+  # ─────────────────────────────────────────────────────────
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
+      - ENABLE_RAG_WEB_SEARCH=${ENABLE_RAG_WEB_SEARCH:-true}
+      - RAG_WEB_SEARCH_ENGINE=${RAG_WEB_SEARCH_ENGINE:-duckduckgo}
+    volumes:
+      - open-webui-data:/app/backend/data
+    networks:
+      - ai
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.open-webui.rule=Host(`ai.${DOMAIN}`)"
+      - "traefik.http.routers.open-webui.entrypoints=websecure"
+      - "traefik.http.routers.open-webui.tls.certresolver=letsencrypt"
+      - "traefik.http.services.open-webui.loadbalancer.server.port=8080"
+
+  # ─────────────────────────────────────────────────────────
+  # Stable Diffusion — 图像生成
+  # ─────────────────────────────────────────────────────────
+  stable-diffusion:
+    image: universonic/stable-diffusion-webui:latest-sha
+    container_name: stable-diffusion
+    restart: unless-stopped
+    environment:
+      - CLI_ARGS=${SD_CLI_ARGS:---listen --port 7860 --enable-insecure-extension-access --api}
+      - NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}
+    volumes:
+      - stable-diffusion-data:/stable-diffusion-webui
+    networks:
+      - ai
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.stable-diffusion.rule=Host(`sd.${DOMAIN}`)"
+      - "traefik.http.routers.stable-diffusion.entrypoints=websecure"
+      - "traefik.http.routers.stable-diffusion.tls.certresolver=letsencrypt"
+      - "traefik.http.services.stable-diffusion.loadbalancer.server.port=7860"
+    deploy:
+      resources:
+        reservations:
+          devices:
+            - driver: nvidia
+              count: all
+              capabilities: [gpu]
+
+  # ─────────────────────────────────────────────────────────
+  # Perplexica — AI 搜索引擎
+  # ─────────────────────────────────────────────────────────
+  perplexica:
+    image: itzcrazykns1337/perplexica:main-sha
+    container_name: perplexica
+    restart: unless-stopped
+    environment:
+      - SEARXNG_API_URL=${SEARXNG_API_URL:-http://searxng:8080}
+      - OLLAMA_URL=${OLLAMA_URL:-http://ollama:11434}
+