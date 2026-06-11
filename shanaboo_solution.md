 ```diff
--- a/stacks/ai/docker-compose.yml
+++ b/stacks/ai/docker-compose.yml
@@ -0,0 +1,168 @@
+services:
+  # ==========================================
+  # Ollama — LLM inference engine
+  # ==========================================
+  ollama:
+    image: ollama/ollama:0.3.12
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0
+      - OLLAMA_ORIGINS=*
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
+      - "traefik.http.routers.ollama.middlewares=authentik@docker"
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
+  ollama-rocm:
+    image: ollama/ollama:0.3.12-rocm
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0
+      - OLLAMA_ORIGINS=*
+      - HSA_OVERRIDE_GFX_9_0_0=${HSA_OVERRIDE_GFX_9_0_0:-}
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
+      - "traefik.http.routers.ollama.middlewares=authentik@docker"
+    profiles:
+      - rocm
+
+  ollama-cpu:
+    image: ollama/ollama:0.3.12
+    container_name: ollama
+    restart: unless-stopped
+    environment:
+      - OLLAMA_HOST=0.0.0.0
+      - OLLAMA_ORIGINS=*
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
+      - "traefik.http.routers.ollama.middlewares=authentik@docker"
+    profiles:
+      - cpu
+
+  # ==========================================
+  # Open WebUI — LLM Web interface
+  # ==========================================
+  open-webui:
+    image: ghcr.io/open-webui/open-webui:0.3.32
+    container_name: open-webui
+    restart: unless-stopped
+    environment:
+      - OLLAMA_BASE_URL=http://ollama:11434
+      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-changeme}
+      - ENABLE_SIGNUP=${WEBUI_ENABLE_SIGNUP:-true}
+      - DEFAULT_MODELS=${WEBUI_DEFAULT_MODELS:-}
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
+      - "traefik.http.routers.open-webui.middlewares=authentik@docker"
+    depends_on:
+      - ollama
+
+  # ==========================================
+  # Stable Diffusion — Image generation
+  # ==========================================
+  stable-diffusion:
+    image: universonic/stable-diffusion-webui:latest-sha
+    container_name: stable-diffusion
+    restart: unless-stopped
+    environment:
+      - CLI_ARGS=--api --listen --enable-insecure-extension-access
+      - NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}
+    volumes:
+      - stable-diffusion-data:/app/stable-diffusion-webui
+    networks:
+      - ai
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.stable-diffusion.rule=Host(`sd.${DOMAIN}`)"
+      - "traefik.http.routers.stable-diffusion.entrypoints=websecure"
+      - "traefik.http.routers.stable-diffusion.tls.certresolver=letsencrypt"
+      - "traefik.http.services.stable-diffusion.loadbalancer.server.port=7860"
+      - "traefik.http.routers.stable-diffusion.middlewares=authentik@docker"
+    deploy:
+      resources:
+        reservations:
+          devices:
+            - driver: nvidia
+              count: all
+              capabilities: [gpu]
+
+networks:
+  ai:
+    external: true
+
+volumes:
+  ollama-data:
+  open-webui-data:
+  stable-diffusion-data:
+
+--- a/stacks/ai/.env.example
+++ b/stacks/ai/.env.example
@@ -0,0 +1,23 @@
+# ==========================================
+# AI Stack Configuration
+# ==========================================
+
+# Base domain for AI services (e.g., ai.example.com)
+DOMAIN=example.com
+
+# GPU Mode: nvidia