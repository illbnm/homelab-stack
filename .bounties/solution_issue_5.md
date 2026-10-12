# Solution for [github/issues_5]: [illbnm/homelab-stack] [BOUNTY $170] Productivity Stack — Gitea + Vaultwarden + Outline + BookStack

- **Reward:** $170.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/5
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 9596 (~$0.0192 USD compute cost)

---

The user wants to implement a productivity stack using Docker Compose, including Gitea, Vaultwarden, Outline, Stirling PDF, and Excalidraw. The services need to be configured with specific requirements, including shared databases (PostgreSQL, Redis), Authentik OIDC integration, MinIO for Outline storage, Traefik for reverse proxy and HTTPS, and various environment variables.

The existing `homelab-stack` repository likely uses Docker Compose and Traefik. I will extend this setup to include the new services.

**Root Cause Analysis / Problem Breakdown:**

1.  **Integration with existing `homelab-stack`:** The solution needs to fit seamlessly into the existing Docker Compose structure, likely using a `docker-compose.yml` and a `.env` file for configuration. Traefik is already in use, so services need appropriate labels.
2.  **Database Management:** PostgreSQL and Redis instances are required. Gitea and Outline will share the PostgreSQL instance. Outline also needs Redis.
3.  **Authentik OIDC:** This is a critical integration point for Gitea and Outline. It requires specific environment variables and configuration within each service.
4.  **MinIO Storage:** Outline needs MinIO for file storage. A MinIO instance needs to be set up and configured.
5.  **SMTP Configuration:** Vaultwarden needs SMTP for email notifications.
6.  **Security:** Disabling public registration for Gitea and Vaultwarden, setting `ADMIN_TOKEN` for Vaultwarden, and ensuring HTTPS for all services (especially Vaultwarden for browser extensions).
7.  **Gitea Actions Runner:** This requires a separate service that connects to the Gitea instance.
8.  **Environment Variables:** A set of specific environment variables must be defined and used.
9.  **Service Specifics:**
    *   **Gitea:** PostgreSQL, Authentik OIDC, disable registration, Gitea Actions runner.
    *   **Vaultwarden:** HTTPS, disable public registration, `ADMIN_TOKEN`, SMTP.
    *   **Outline:** PostgreSQL, Redis, Authentik OIDC, MinIO.
    *   **Stirling PDF:** Basic setup, Traefik.
    *   **Excalidraw:** Basic setup, Traefik.

**Architecture Design:**

The solution will involve:

1.  **`docker-compose.yml`:**
    *   Add new services: `gitea`, `vaultwarden`, `outline`, `stirling-pdf`, `excalidraw`, `gitea-runner`, `minio`, `postgresql`, `redis`.
    *   Configure Traefik labels for each web-facing service.
    *   Define volumes for persistent data.
    *   Set up network for inter-service communication.
2.  **`.env` file:**
    *   Add all required environment variables, including database credentials, OIDC client IDs/secrets, MinIO credentials, SMTP details, and service-specific tokens/secrets.
    *   Placeholder values will be provided, requiring the user to fill them in.
3.  **Traefik Configuration:** Ensure existing Traefik setup correctly routes traffic and handles HTTPS for the new services. This will primarily be done via Docker labels in `docker-compose.yml`.
4.  **Authentik Setup (External to this solution, but required context):** The user is expected to have an Authentik instance running and configured with OIDC providers for Gitea and Outline, including redirect URIs.
    *   Gitea Redirect URI: `https://gitea.YOUR_DOMAIN/user/oauth2/Authentik/callback`
    *   Outline Redirect URI: `https://outline.YOUR_DOMAIN/auth/oidc.callback`
5.  **MinIO Setup:** A MinIO service will be added, and Outline will be configured to use it as an S3-compatible storage backend.
6.  **Gitea Actions Runner:** A separate `gitea-runner` service will be added, configured to connect to the Gitea instance.

**Detailed Implementation Plan:**

1.  **Update `docker-compose.yml`:**
    *   Add `postgresql` service (if not already present, otherwise configure it for Gitea/Outline).
    *   Add `redis` service for Outline.
    *   Add `minio` service and `minio-client` (for bucket creation).
    *   Add `gitea` service with PostgreSQL, Traefik, and OIDC configuration.
    *   Add `gitea-runner` service.
    *   Add `vaultwarden` service with Traefik, HTTPS, admin token, and SMTP configuration.
    *   Add `outline` service with PostgreSQL, Redis, MinIO, Traefik, and OIDC configuration.
    *   Add `stirling-pdf` service with Traefik.
    *   Add `excalidraw` service with Traefik.
    *   Define necessary volumes.
    *   Ensure all services are on the same Docker network as Traefik.

2.  **Update `.env`:**
    *   Add `POSTGRES_PASSWORD` (for the shared PostgreSQL instance).
    *   Add `GITEA_DB_PASSWORD`, `GITEA_OIDC_CLIENT_ID`, `GITEA_OIDC_CLIENT_SECRET`, `GITEA_OIDC_METADATA_URL`, `GITEA_OIDC_SCOPES`, `GITEA_OIDC_AUTH_URL`, `GITEA_OIDC_TOKEN_URL`, `GITEA_OIDC_USERINFO_URL`.
    *   Add `VAULTWARDEN_ADMIN_TOKEN`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM_ADDRESS`, `SMTP_SSL`.
    *   Add `OUTLINE_SECRET_KEY`, `OUTLINE_UTILS_SECRET`, `OUTLINE_OIDC_CLIENT_ID`, `OUTLINE_OIDC_CLIENT_SECRET`, `OUTLINE_OIDC_AUTH_URL`, `OUTLINE_OIDC_TOKEN_URL`, `OUTLINE_OIDC_USERINFO_URL`, `OUTLINE_OIDC_JWKS_URL`, `OUTLINE_S3_ACCESS_KEY_ID`, `OUTLINE_S3_SECRET_ACCESS_KEY`, `OUTLINE_S3_BUCKET_NAME`, `OUTLINE_S3_ENDPOINT`.
    *   Add `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`.
    *   Add `GITEA_RUNNER_TOKEN`.
    *   Add `GITEA_DOMAIN`, `VAULTWARDEN_DOMAIN`, `OUTLINE_DOMAIN`, `STIRLING_PDF_DOMAIN`, `EXCALIDRAW_DOMAIN` for Traefik routing.

3.  **MinIO Bucket Initialization:** Use an `init-minio` service that runs `mc mb` to create the bucket for Outline. This service should run once and then exit.

**Pre-requisites for the user:**

*   A working Traefik setup (as implied by `homelab-stack`).
*   An Authentik instance with OIDC providers configured for Gitea and Outline.
    *   **Gitea OIDC Provider:**
        *   Name: `Authentik` (or whatever you prefer, but match `GITEA_OIDC_NAME`)
        *   Authorization flow: `default-provider-authorization-explicit-consent`
        *   Client ID: `GITEA_OIDC_CLIENT_ID`
        *   Client Secret: `GITEA_OIDC_CLIENT_SECRET`
        *   Redirect URIs: `https://gitea.YOUR_DOMAIN/user/oauth2/Authentik/callback`
        *   Scopes: `openid profile email`
        *   Issuer: `https://authentik.YOUR_DOMAIN/application/o/gitea/` (or similar, check Authentik UI)
    *   **Outline OIDC Provider:**
        *   Name: `Authentik` (or whatever you prefer, but match `OUTLINE_OIDC_NAME`)
        *   Authorization flow: `default-provider-authorization-explicit-consent`
        *   Client ID: `OUTLINE_OIDC_CLIENT_ID`
        *   Client Secret: `OUTLINE_OIDC_CLIENT_SECRET`
        *   Redirect URIs: `https://outline.YOUR_DOMAIN/auth/oidc.callback`
        *   Scopes: `openid profile email`
        *   Issuer: `https://authentik.YOUR_DOMAIN/application/o/outline/` (or similar, check Authentik UI)
*   DNS records pointing `gitea.YOUR_DOMAIN`, `vaultwarden.YOUR_DOMAIN`, `outline.YOUR_DOMAIN`, `stirling-pdf.YOUR_DOMAIN`, `excalidraw.YOUR_DOMAIN` to the server's IP.

---

### File: docker-compose.yml
```yaml
# This file should be merged with the existing docker-compose.yml
# Add these services to your existing docker-compose.yml
# Ensure your Traefik service and network are already defined.

version: '3.8'

networks:
  # Assuming you have a 'proxy' network for Traefik
  proxy:
    external: true
  # Internal network for services that don't need direct external access
  internal:
    internal: true

volumes:
  gitea_data:
  vaultwarden_data:
  outline_data:
  minio_data:
  postgresql_data:
  redis_data:

services:
  # --- Database Services ---
  postgresql:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: gitea
      POSTGRES_USER: gitea
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD} # Shared password for Gitea and Outline
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    networks:
      - internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gitea -d gitea"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - internal
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  # --- MinIO Object Storage for Outline ---
  minio:
    image: quay.io/minio/minio:latest
    restart: unless-stopped
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      MINIO_SERVER_URL: https://${MINIO_DOMAIN} # Optional, for MinIO console
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    networks:
      - proxy
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.minio.entrypoints=websecure"
      - "traefik.http.routers.minio.rule=Host(`${MINIO_DOMAIN}`)"
      - "traefik.http.routers.minio.tls=true"
      - "traefik.http.routers.minio.service=minio"
      - "traefik.http.services.minio.loadbalancer.server.port=9000" # S3 API port
      - "traefik.http.routers.minio-console.entrypoints=websecure"
      - "traefik.http.routers.minio-console.rule=Host(`console.${MINIO_DOMAIN}`)" # Separate domain for console
      - "traefik.http.routers.minio-console.tls=true"
      - "traefik.http.routers.minio-console.service=minio-console"
      - "traefik.http.services.minio-console.loadbalancer.server.port=9001" # Console port
      - "traefik.docker.network=proxy"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  # MinIO Client to create bucket for Outline
  init-minio:
    image: minio/mc
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
      /usr/bin/mc config host add myminio http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD};
      /usr/bin/mc mb myminio/${OUTLINE_S3_BUCKET_NAME} --ignore-existing;
      exit 0;
      "
    networks:
      - internal
    # This service should run once and then exit
    restart: "no"

  # --- Gitea ---
  gitea:
    image: gitea/gitea:1.22.2
    restart: unless-stopped
    depends_on:
      postgresql:
        condition: service_healthy
    environment:
      # Database Configuration
      DB_TYPE: postgres
      DB_HOST: postgresql:5432
      DB_NAME: gitea
      DB_USER: gitea
      DB_PASSWD: ${POSTGRES_PASSWORD}
      # Gitea General Configuration
      APP_NAME: Gitea
      RUN_MODE: prod
      # Server Configuration
      SERVER_SSH_DOMAIN: ${GITEA_DOMAIN}
      SERVER_SSH_PORT: 22 # If you expose SSH directly, otherwise leave as default
      SERVER_SSH_LISTEN_PORT: 22 # Internal port
      SERVER_DOMAIN: ${GITEA_DOMAIN}
      SERVER_ROOT_URL: https://${GITEA_DOMAIN}/
      # OIDC Configuration
      OAUTH2_OIDC_ENABLED: "true"
      OAUTH2_OIDC_AUTO_DISCOVER_URL: ${GITEA_OIDC_METADATA_URL}
      OAUTH2_OIDC_CLIENT_ID: ${GITEA_OIDC_CLIENT_ID}
      OAUTH2_OIDC_CLIENT_SECRET: ${GITEA_OIDC_CLIENT_SECRET}
      OAUTH2_OIDC_SCOPES: "openid profile email"
      OAUTH2_OIDC_NAME: "Authentik" # Name displayed on login page
      OAUTH2_OIDC_GROUP_CLAIM_NAME: "groups" # Optional, if you use groups
      # Disable registration
      SERVICE_DISABLE_REGISTRATION: "true"
      SERVICE_ENABLE_NOTIFY_MAIL: "true" # Enable email notifications
      # SMTP Configuration (optional, Gitea can also use SMTP)
      # SMTP_HOST: ${SMTP_HOST}:${SMTP_PORT}
      # SMTP_FROM: ${SMTP_FROM_ADDRESS}
      # SMTP_USER: ${SMTP_USER}
      # SMTP_PASSWD: ${SMTP_PASS}
      # SMTP_ENCRYPT: ssl # or tls or none
      # Actions Configuration
      ACTIONS_ENABLED: "true"
      ACTIONS_LOG_STORAGE_TYPE: "minio" # Or "local" if you prefer
      ACTIONS_LOG_MINIO_ENDPOINT: "minio:9000"
      ACTIONS_LOG_MINIO_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
      ACTIONS_LOG_MINIO_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
      ACTIONS_LOG_MINIO_BUCKET: "gitea-actions-logs" # New bucket for Gitea Actions
      ACTIONS_LOG_MINIO_LOCATION: "us-east-1"
      ACTIONS_LOG_MINIO_USE_SSL: "false" # Internal communication
    volumes:
      - gitea_data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - proxy
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.entrypoints=websecure"
      - "traefik.http.routers.gitea.rule=Host(`${GITEA_DOMAIN}`)"
      - "traefik.http.routers.gitea.tls=true"
      - "traefik.http.routers.gitea.service=gitea"
      - "traefik.http.services.gitea.loadbalancer.server.port=3000"
      - "traefik.docker.network=proxy"
      # Optional: For SSH access via Traefik (requires Traefik TCP router)
      # - "traefik.tcp.routers.gitea-ssh.entrypoints=ssh"
      # - "traefik.tcp.routers.gitea-ssh.rule=HostSNI(`*`)" # Or HostSNI(`gitea.yourdomain.com`) if you have a dedicated SSH domain
      # - "traefik.tcp.routers.gitea-ssh.service=gitea-ssh"
      # - "traefik.tcp.services.gitea-ssh.loadbalancer.server.port=22"

  # Gitea Actions Runner
  gitea-runner:
    image: gitea/act_runner:latest
    restart: unless-stopped
    depends_on:
      gitea:
        condition: service_healthy
    environment:
      GITEA_RUNNER_NAME: "docker-runner"
      GITEA_RUNNER_LABELS: "ubuntu-latest:docker"
      GITEA_INSTANCE_URL: "http://gitea:3000" # Internal Gitea URL
      GITEA_RUNNER_TOKEN: ${GITEA_RUNNER_TOKEN} # Generate this in Gitea UI
      # Optional: Docker-in-Docker setup for runner
      DOCKER_HOST: "unix:///var/run/docker.sock"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Mount Docker socket for D-in-D
      - gitea_runner_data:/data # For runner's internal data
    networks:
      - internal
    # This runner needs to be registered with Gitea manually or via a setup script
    # For initial setup, you might run it once with `entrypoint: /usr/bin/dumb-init /app/gitea-runner register`
    # and then replace with the default entrypoint.

  # --- Vaultwarden (Bitwarden compatible) ---
  vaultwarden:
    image: vaultwarden/server:1.32.0
    restart: unless-stopped
    environment:
      WEBSOCKET_ENABLED: "true"
      SIGNUPS_ALLOWED: "false" # Disable public registration
      ADMIN_TOKEN: ${VAULTWARDEN_ADMIN_TOKEN} # Protect admin page
      DOMAIN: https://${VAULTWARDEN_DOMAIN} # Required for browser extensions
      # SMTP Configuration
      SMTP_HOST: ${SMTP_HOST}
      SMTP_PORT: ${SMTP_PORT}
      SMTP_FROM: ${SMTP_FROM_ADDRESS}
      SMTP_USERNAME: ${SMTP_USER}
      SMTP_PASSWORD: ${SMTP_PASS}
      SMTP_SSL: ${SMTP_SSL} # true or false
      SMTP_ACCEPT_INVALID_CERTS: "false" # Set to true if using self-signed SMTP
      # Optional: Push notifications
      # PUSH_ENABLED: "true"
      # PUSH_INSTALLATION_ID: "..."
      # PUSH_INSTALLATION_KEY: "..."
    volumes:
      - vaultwarden_data:/data
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.vaultwarden.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden.rule=Host(`${VAULTWARDEN_DOMAIN}`)"
      - "traefik.http.routers.vaultwarden.tls=true"
      - "traefik.http.routers.vaultwarden.service=vaultwarden"
      - "traefik.http.services.vaultwarden.loadbalancer.server.port=80"
      # Websocket for real-time updates
      - "traefik.http.routers.vaultwarden-ws.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden-ws.rule=Host(`${VAULTWARDEN_DOMAIN}`) && Path(`/notifications/hub`)"
      - "traefik.http.routers.vaultwarden-ws.tls=true"
      - "traefik.http.routers.vaultwarden-ws.service=vaultwarden-ws"
      - "traefik.http.services.vaultwarden-ws.loadbalancer.server.port=3012" # Websocket port
      - "traefik.docker.network=proxy"

  # --- Outline Wiki ---
  outline:
    image: outlinewiki/outline:0.80.2
    restart: unless-stopped
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
      init-minio:
        condition: service_completed_successfully
    environment:
      # General
      URL: https://${OUTLINE_DOMAIN}
      PORT: 80
      SECRET_KEY: ${OUTLINE_SECRET_KEY}
      UTILS_SECRET: ${OUTLINE_UTILS_SECRET}
      # Database
      DATABASE_URL: postgresql://gitea:${POSTGRES_PASSWORD}@postgresql:5432/gitea?sslmode=disable
      # Redis
      REDIS_URL: redis://redis:6379
      # OIDC Configuration
      OIDC_CLIENT_ID: ${OUTLINE_OIDC_CLIENT_ID}
      OIDC_CLIENT_SECRET: ${OUTLINE_OIDC_CLIENT_SECRET}
      OIDC_AUTH_URL: ${OUTLINE_OIDC_AUTH_URL}
      OIDC_TOKEN_URL: ${OUTLINE_OIDC_TOKEN_URL}
      OIDC_USERINFO_URL: ${OUTLINE_OIDC_USERINFO_URL}
      OIDC_JWKS_URL: ${OUTLINE_OIDC_JWKS_URL}
      OIDC_SCOPES: "openid profile email"
      OIDC_DISPLAY_NAME: "Authentik" # Name displayed on login page
      # S3 Storage (MinIO compatible)
      AWS_ACCESS_KEY_ID: ${OUTLINE_S3_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${OUTLINE_S3_SECRET_ACCESS_KEY}
      AWS_REGION: us-east-1 # MinIO doesn't strictly use regions, but a value is needed
      AWS_S3_UPLOAD_BUCKET_URL: https://${MINIO_DOMAIN}/${OUTLINE_S3_BUCKET_NAME}
      AWS_S3_UPLOAD_BUCKET_NAME: ${OUTLINE_S3_BUCKET_NAME}
      AWS_S3_FORCE_PATH_STYLE: "true" # Required for MinIO
      AWS_S3_ENDPOINT: http://minio:9000 # Internal MinIO endpoint
      # Optional: SMTP for Outline
      # SMTP_HOST: ${SMTP_HOST}
      # SMTP_PORT: ${SMTP_PORT}
      # SMTP_USERNAME: ${SMTP_USER}
      # SMTP_PASSWORD: ${SMTP_PASS}
      # SMTP_FROM_EMAIL: ${SMTP_FROM_ADDRESS}
      # SMTP_SECURE: ${SMTP_SSL} # true or false
    volumes:
      - outline_data:/opt/app/public/uploads # For local file uploads if not using S3 (but we are)
    networks:
      - proxy
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.outline.entrypoints=websecure"
      - "traefik.http.routers.outline.rule=Host(`${OUTLINE_DOMAIN}`)"
      - "traefik.http.routers.outline.tls=true"
      - "traefik.http.routers.outline.service=outline"
      - "traefik.http.services.outline.loadbalancer.server.port=80"
      - "traefik.docker.network=proxy"

  # --- Stirling PDF ---
  stirling-pdf:
    image: frooodle/s-pdf:0.30.2
    restart: unless-stopped
    environment:
      # Optional: Configure for specific needs
      # APP_LOCALE: en_US
      # APP_MAX_FILE_SIZE_MB: 100
      # APP_ENABLE_AUTH: "false" # If you want to add basic auth
    volumes:
      - ./stirling-pdf-data:/usr/share/stirling-pdf/data # For persistent settings/files
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.stirling-pdf.entrypoints=websecure"
      - "traefik.http.routers.stirling-pdf.rule=Host(`${STIRLING_PDF_DOMAIN}`)"
      - "traefik.http.routers.stirling-pdf.tls=true"
      - "traefik.http.routers.stirling-pdf.service=stirling-pdf"
      - "traefik.http.services.stirling-pdf.loadbalancer.server.port=8080"
      - "traefik.docker.network=proxy"

  # --- Excalidraw ---
  excalidraw:
    image: excalidraw/excalidraw:latest-sha
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.excalidraw.entrypoints=websecure"
      - "traefik.http.routers.excalidraw.rule=Host(`${EXCALIDRAW_DOMAIN}`)"
      - "traefik.http.routers.excalidraw.tls=true"
      - "traefik.http.routers.excalidraw.service=excalidraw"
      - "traefik.http.services.excalidraw.loadbalancer.server.port=80"
      - "traefik.docker.network=proxy"

```

### File: .env.example
```bash
# This file should be copied to .env and filled with your actual values.
# Ensure your Traefik setup is already configured and working.

# --- General Configuration ---
# Your main domain for the homelab stack
# Example: YOUR_DOMAIN=homelab.example.com
YOUR_DOMAIN=

# --- Traefik Domains ---
# Set these to your desired subdomains.
# Example: GITEA_DOMAIN=gitea.homelab.example.com
GITEA_DOMAIN=gitea.${YOUR_DOMAIN}
VAULTWARDEN_DOMAIN=vaultwarden.${YOUR_DOMAIN}
OUTLINE_DOMAIN=outline.${YOUR_DOMAIN}
STIRLING_PDF_DOMAIN=stirling-pdf.${YOUR_DOMAIN}
EXCALIDRAW_DOMAIN=excalidraw.${YOUR_DOMAIN}
MINIO_DOMAIN=minio.${YOUR_DOMAIN} # For MinIO console and S3 endpoint

# --- Database Passwords ---
# Shared PostgreSQL password for Gitea and Outline
POSTGRES_PASSWORD=your_strong_postgres_password_here

# --- SMTP Configuration (for Vaultwarden and optionally Gitea/Outline) ---
SMTP_HOST=your_smtp_host.com
SMTP_PORT=587 # or 465 for SSL
SMTP_USER=your_smtp_username
SMTP_PASS=your_smtp_password
SMTP_FROM_ADDRESS=no-reply@${YOUR_DOMAIN}
SMTP_SSL=true # Set to true for SMTPS (port 465) or STARTTLS (port 587)

# --- Gitea Configuration ---
# Gitea OIDC (Authentik)
# Create an OIDC provider in Authentik for Gitea.
# Redirect URI: https://gitea.YOUR_DOMAIN/user/oauth2/Authentik/callback
GITEA_OIDC_CLIENT_ID=your_gitea_oidc_client_id
GITEA_OIDC_CLIENT_SECRET=your_gitea_oidc_client_secret
# Authentik's OIDC discovery URL for your Gitea application
# Example: https://authentik.YOUR_DOMAIN/application/o/gitea/.well-known/openid-configuration
GITEA_OIDC_METADATA_URL=https://authentik.${YOUR_DOMAIN}/application/o/gitea/.well-known/openid-configuration

# Gitea Actions Runner Token
# Generate this token in Gitea UI: Site Administration -> Actions -> Runners -> New Runner
GITEA_RUNNER_TOKEN=your_gitea_runner_registration_token

# --- Vaultwarden Configuration ---
# Generate a strong token for Vaultwarden admin page access.
# Access at https://vaultwarden.YOUR_DOMAIN/admin
VAULTWARDEN_ADMIN_TOKEN=your_strong_vaultwarden_admin_token

# --- Outline Configuration ---
# Generate strong, random keys for Outline
OUTLINE_SECRET_KEY=your_outline_secret_key_random_string
OUTLINE_UTILS_SECRET=your_outline_utils_secret_random_string

# Outline OIDC (Authentik)
# Create an OIDC provider in Authentik for Outline.
# Redirect URI: https://outline.YOUR_DOMAIN/auth/oidc.callback
OUTLINE_OIDC_CLIENT_ID=your_outline_oidc_client_id
OUTLINE_OIDC_CLIENT_SECRET=your_outline_oidc_client_secret
# Authentik's OIDC endpoints for your Outline application
# Example: https://authentik.YOUR_DOMAIN/application/o/outline/
OUTLINE_OIDC_AUTH_URL=https://authentik.${YOUR_DOMAIN}/application/o/outline/authorize
OUTLINE_OIDC_TOKEN_URL=https://authentik.${YOUR_DOMAIN}/application/o/outline/token
OUTLINE_OIDC_USERINFO_URL=https://authentik.${YOUR_DOMAIN}/application/o/outline/userinfo
OUTLINE_OIDC_JWKS_URL=https://authentik.${YOUR_DOMAIN}/application/o/outline/jwks

# Outline S3 Storage (MinIO)
MINIO_ROOT_USER=your_minio_root_username
MINIO_ROOT_PASSWORD=your_minio_root_password
OUTLINE_S3_ACCESS_KEY_ID=${MINIO_ROOT_USER} # Using MinIO root user for simplicity, consider dedicated user
OUTLINE_S3_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD} # Using MinIO root password
OUTLINE_S3_BUCKET_NAME=outline-uploads # Name of the S3 bucket for Outline files

```

### File: README.md (Update section for new services)
```markdown
# Homelab Stack

This repository contains a collection of Docker Compose configurations for self-hosting various services in a homelab environment, managed by Traefik for reverse proxy and HTTPS.

## Services Included

... (existing services) ...

### Productivity Stack

This section details the setup for a comprehensive productivity suite, including:

*   **Gitea**: Self-hosted Git service with Actions runner and Authentik OIDC.
*   **Vaultwarden**: Bitwarden-compatible password manager with HTTPS and admin token.
*   **Outline**: Collaborative knowledge base with Authentik OIDC and MinIO storage.
*   **Stirling PDF**: Powerful PDF manipulation tool.
*   **Excalidraw**: Online whiteboard for sketching diagrams.
*   **MinIO**: S3-compatible object storage, used by Outline and Gitea Actions.
*   **PostgreSQL**: Shared database for Gitea and Outline.
*   **Redis**: Caching and queue for Outline.

## Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/illbnm/homelab-stack.git
    cd homelab-stack
    ```

2.  **Ensure Traefik is running:**
    This stack assumes you have Traefik already set up and running, configured to use a Docker network (e.g., `proxy`) and handling HTTPS certificates (e.g., via Let's Encrypt). If not, please refer to the Traefik documentation or other examples in this repository to set it up first.

3.  **Configure `.env` file:**
    Copy the `.env.example` file to `.env` and fill in all the placeholder values.
    ```bash
    cp .env.example .env
    # Edit .env with your preferred editor
    nano .env
    ```
    **Important variables to configure:**
    *   `YOUR_DOMAIN`: Your base domain (e.g., `example.com`).
    *   `GITEA_DOMAIN`, `VAULTWARDEN_DOMAIN`, `OUTLINE_DOMAIN`, `STIRLING_PDF_DOMAIN`, `EXCALIDRAW_DOMAIN`, `MINIO_DOMAIN`: Your desired subdomains for each service. Ensure DNS records for these subdomains point to your server's IP address.
    *   `POSTGRES_PASSWORD`: A strong password for the shared PostgreSQL database.
    *   `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM_ADDRESS`, `SMTP_SSL`: Your SMTP server details for email notifications (Vaultwarden, optionally Gitea/Outline).
    *   `GITEA_OIDC_CLIENT_ID`, `GITEA_OIDC_CLIENT_SECRET`, `GITEA_OIDC_METADATA_URL`: Authentik OIDC details for Gitea.
    *   `GITEA_RUNNER_TOKEN`: This token needs to be generated *after* Gitea is running. See "Post-Deployment Steps" for Gitea.
    *   `VAULTWARDEN_ADMIN_TOKEN`: A strong token to secure the Vaultwarden admin panel.
    *   `OUTLINE_SECRET_KEY`, `OUTLINE_UTILS_SECRET`: Strong, random keys for Outline.
    *   `OUTLINE_OIDC_CLIENT_ID`, `OUTLINE_OIDC_CLIENT_SECRET`, `OUTLINE_OIDC_AUTH_URL`, `OUTLINE_OIDC_TOKEN_URL`, `OUTLINE_OIDC_USERINFO_URL`, `OUTLINE_OIDC_JWKS_URL`: Authentik OIDC details for Outline.
    *   `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`: Credentials for MinIO.
    *   `OUTLINE_S3_BUCKET_NAME`: The name of the S3 bucket Outline will use in Min

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
