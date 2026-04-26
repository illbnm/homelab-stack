#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Fixtures & Mock Environment Generator
# Generates mock .env and config files for CI/DinD testing.
# =============================================================================

FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# generate_mock_env — Create a minimal .env for testing
generate_mock_env() {
    local outfile="${1:-${REPO_ROOT}/.env.test}"
    cat > "$outfile" <<'ENVEOF'
# Auto-generated test environment — DO NOT use in production
TZ=UTC
PUID=1000
PGID=1000
DOMAIN=test.homelab.local
ACME_EMAIL=test@homelab.local

# Traefik
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD_HASH=$apr1$test$test

# Authentik
AUTHENTIK_SECRET_KEY=test-secret-key-32chars-minimum-x
AUTHENTIK_POSTGRES_PASSWORD=test-pg-pass
AUTHENTIK_REDIS_PASSWORD=test-redis-pass
AUTHENTIK_ADMIN_EMAIL=admin@test.homelab.local
AUTHENTIK_ADMIN_PASSWORD=testpass123
AUTHENTIK_DOMAIN=auth.test.homelab.local

# Databases
POSTGRES_ROOT_USER=postgres
POSTGRES_ROOT_PASSWORD=test-pg-root
REDIS_PASSWORD=test-redis
MARIADB_ROOT_PASSWORD=test-mariadb-root

# Per-service DB
GITEA_DB_PASSWORD=test-gitea-db
NEXTCLOUD_DB_PASSWORD=test-nextcloud-db
OUTLINE_DB_PASSWORD=test-outline-db
AUTHENTIK_DB_PASSWORD=test-authentik-db

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=test-grafana

# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=test-vault-token-48chars-minimum-xxxxxxxxxxxxx

# WireGuard
WG_HOST=127.0.0.1
WG_PASSWORD=testpass
WG_PORT=51820
WG_PASSWORD_HASH=

# Cloudflare (dummy)
CF_API_TOKEN=test-cf-token
CF_ZONE_ID=test-zone-id
CF_RECORD_NAME=test.homelab.local

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=test-nextcloud

# Media
MEDIA_ROOT=/tmp/homelab-test/media
DOWNLOADS_ROOT=/tmp/homelab-test/downloads
MEDIA_PATH=/tmp/homelab-test/media

# AI
OLLAMA_GPU_ENABLED=false
WEBUI_SECRET_KEY=test-webui-secret-32chars-xxxxxx

# Notifications
GOTIFY_PASSWORD=test-gotify
NTFY_AUTH_ENABLED=false

# MQTT
MQTT_USER=testuser
MQTT_PASSWORD=testpass
MQTT_PORT=1883
MQTT_WS_PORT=9001

# Network
HTTP_PROXY=
HTTPS_PROXY=
NO_PROXY=localhost,127.0.0.1
DOCKER_PROXY_ENABLED=false
CN_MODE=false

# Dashboard
SECRET_ENCRYPTION_KEY=test-encryption-key-32chars-xxxx
ENVEOF
    echo "Generated mock .env at: $outfile"
}

# generate_mock_traefik_config — Create minimal Traefik static config for tests
generate_mock_traefik_config() {
    local config_dir="${REPO_ROOT}/config/traefik"
    mkdir -p "$config_dir/dynamic"

    cat > "$config_dir/traefik.yml" <<'EOF'
# Test Traefik config
api:
  dashboard: true
  insecure: true

ping:
  entryPoint: web

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    directory: /dynamic
    watch: true

log:
  level: INFO
EOF

    cat > "$config_dir/dynamic/test.yml" <<'EOF'
http:
  middlewares:
    security-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        frameDeny: true
EOF

    touch "$config_dir/acme.json"
    chmod 600 "$config_dir/acme.json" 2>/dev/null || true
    echo "Generated mock Traefik config at: $config_dir"
}

# generate_mock_prometheus_config — Create minimal Prometheus config for tests
generate_mock_prometheus_config() {
    local config_dir="${REPO_ROOT}/config/prometheus"
    mkdir -p "$config_dir/rules"

    cat > "$config_dir/prometheus.yml" <<'EOF'
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
    echo "Generated mock Prometheus config at: $config_dir"
}

# generate_mock_loki_config
generate_mock_loki_config() {
    local config_dir="${REPO_ROOT}/config/loki"
    mkdir -p "$config_dir"

    cat > "$config_dir/loki-config.yml" <<'EOF'
auth_enabled: false
server:
  http_listen_port: 3100
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
EOF

    cat > "$config_dir/promtail-config.yml" <<'EOF'
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
scrape_configs: []
EOF
    echo "Generated mock Loki config at: $config_dir"
}

# generate_mock_alertmanager_config
generate_mock_alertmanager_config() {
    local config_dir="${REPO_ROOT}/config/alertmanager"
    mkdir -p "$config_dir"
    cat > "$config_dir/alertmanager.yml" <<'EOF'
route:
  receiver: 'null'
receivers:
  - name: 'null'
EOF
    echo "Generated mock Alertmanager config at: $config_dir"
}

# generate_mock_grafana_config
generate_mock_grafana_config() {
    local config_dir="${REPO_ROOT}/config/grafana/provisioning"
    mkdir -p "$config_dir/datasources" "$config_dir/dashboards"
    cat > "$config_dir/datasources/prometheus.yml" <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
    cat > "$config_dir/dashboards/default.yml" <<'EOF'
apiVersion: 1
providers: []
EOF
    echo "Generated mock Grafana config at: $config_dir"
}

# setup_test_fixtures — Generate all mock configs needed for testing
setup_test_fixtures() {
    echo "Setting up test fixtures..."
    generate_mock_env
    generate_mock_traefik_config
    generate_mock_prometheus_config
    generate_mock_loki_config
    generate_mock_alertmanager_config
    generate_mock_grafana_config
    mkdir -p /tmp/homelab-test/media /tmp/homelab-test/downloads 2>/dev/null || true
    echo "Test fixtures ready."
}

# cleanup_test_fixtures
cleanup_test_fixtures() {
    echo "Cleaning up test fixtures..."
    rm -f "${REPO_ROOT}/.env.test"
    rm -rf /tmp/homelab-test 2>/dev/null || true
    echo "Cleanup complete."
}
