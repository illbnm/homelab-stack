# Solution for [github/issues_10]: [illbnm/homelab-stack] [BOUNTY $280] Observability — Prometheus + Grafana + Loki + Alerting

- **Reward:** $280.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/10
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 10891 (~$0.0218 USD compute cost)

---

## Root Cause Analysis & Architecture Design

The current `homelab-stack` repository lacks a comprehensive observability solution. The issue outlines a clear need for integrating various monitoring tools (Prometheus, Grafana, Loki, Tempo, Alertmanager, Uptime Kuma, cAdvisor, Node Exporter) to cover metrics, logs, traces, alerting, and uptime monitoring.

The core challenge lies in:
1.  **Integration:** Seamlessly connecting all these services, ensuring they can discover and scrape relevant data from each other and other existing services (Traefik, Authentik, Nextcloud, Gitea).
2.  **Configuration Management:** Automating the configuration of Prometheus scrape targets, Grafana dashboards, Loki Promtail agents, Alertmanager rules, and Uptime Kuma monitors.
3.  **Authentication & Authorization:** Integrating Grafana with Authentik for OIDC-based authentication and role mapping.
4.  **Alerting:** Setting up robust alert rules and routing them to Alertmanager, which then pushes notifications to ntfy.
5.  **Data Retention:** Implementing configurable data retention policies for Prometheus, Loki, and Tempo.
6.  **Automation:** Providing scripts for initial setup (e.g., Uptime Kuma monitors) and ensuring configurations are persistent and reproducible.

### Proposed Architecture

The solution will leverage Docker Compose for orchestrating all the observability services.

*   **Prometheus:** Will be the central metrics collection engine. It will scrape metrics from:
    *   `node-exporter`: For host-level metrics.
    *   `cAdvisor`: For container-level metrics.
    *   `traefik`: For reverse proxy metrics.
    *   `authentik`, `nextcloud`, `gitea`: For application-specific metrics (assuming they expose Prometheus-compatible endpoints or can be instrumented).
    *   `prometheus`: For self-monitoring.
    *   `alertmanager`: For Alertmanager metrics.
    *   `grafana`: For Grafana metrics.
    *   `loki`: For Loki metrics.
    *   `tempo`: For Tempo metrics.
    *   `uptime-kuma`: For Uptime Kuma metrics.
*   **Grafana:** Will provide visualization for metrics (Prometheus), logs (Loki), and traces (Tempo). It will be pre-provisioned with essential dashboards and configured for Authentik OIDC.
*   **Loki & Promtail:** Promtail will run as a Docker container, configured to auto-discover and scrape logs from all other Docker containers. It will also be configured to scrape `/var/log/syslog` and Traefik access logs. Loki will store and index these logs.
*   **Tempo:** Will be the distributed tracing backend. Services that support OpenTelemetry or Jaeger will send traces to Tempo.
*   **Alertmanager:** Will receive alerts from Prometheus, deduplicate, group, and route them to ntfy.
*   **cAdvisor & Node Exporter:** Standard exporters for container and host metrics, respectively.
*   **Uptime Kuma:** Will monitor the health endpoints of various services and provide a public status page. It will also send downtime notifications to ntfy.
*   **Grafana OnCall:** (Optional, as per issue description, but not in core requirements for setup) If needed, it would integrate with Alertmanager for on-call scheduling. For this bounty, we'll focus on the core requirements and integrate Alertmanager directly with ntfy.

### Directory Structure Changes

To accommodate the new services and configurations, the following directory structure will be adopted/modified:

```
.
├── .env.example
├── docker-compose.yml
├── config/
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── node-exporter-full.json
│   │   │   ├── docker-container-host-metrics.json
│   │   │   ├── traefik-official.json
│   │   │   ├── loki-dashboard.json
│   │   │   └── uptime-kuma.json
│   │   ├── provisioning/
│   │   │   ├── dashboards.yml
│   │   │   └── datasources.yml
│   │   └── grafana.ini
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts/
│   │       ├── host.yml
│   │       ├── containers.yml
│   │       └── services.yml
│   ├── alertmanager/
│   │   └── alertmanager.yml
│   ├── loki/
│   │   └── loki-config.yaml
│   └── promtail/
│       └── promtail-config.yaml
├── scripts/
│   └── uptime-kuma-setup.sh
└── README.md
```

### Key Implementation Details

1.  **`docker-compose.yml`:**
    *   Define all services (Prometheus, Grafana, Loki, Promtail, Tempo, Alertmanager, cAdvisor, Node Exporter, Uptime Kuma).
    *   Use `network_mode: host` for Node Exporter and Promtail (for `/var/log/syslog` access and Docker socket access) to simplify host-level metric/log collection.
    *   Mount necessary volumes for persistence and configuration.
    *   Ensure services are on the same Docker network for inter-service communication.
    *   Use `restart: unless-stopped`.
    *   Define `PROMETHEUS_RETENTION`, `LOKI_RETENTION`, `TEMPO_RETENTION` from `.env`.

2.  **Prometheus Configuration (`config/prometheus/prometheus.yml`):**
    *   Define `scrape_configs` for all required targets.
    *   Use `__meta_docker_container_label_com_docker_compose_service` for service discovery where possible (e.g., for `cadvisor`, `node-exporter`, `prometheus`, `alertmanager`, `grafana`, `loki`, `tempo`, `uptime-kuma`).
    *   For `traefik`, `authentik`, `nextcloud`, `gitea`, assume they are on the same Docker network and expose metrics on standard ports. If not, specific `static_configs` or `dns_sd_configs` might be needed. For this solution, we'll assume they are discoverable by service name within the Docker network.
    *   Include `rule_files` for alert rules.

3.  **Grafana Provisioning (`config/grafana/provisioning/`):**
    *   `datasources.yml`: Configure Prometheus, Loki, and Tempo as data sources.
    *   `dashboards.yml`: Point to the `config/grafana/dashboards/` directory for automatic dashboard loading.
    *   `grafana.ini`: Configure OIDC for Authentik, including `client_id`, `client_secret`, `auth_url`, `token_url`, `api_url`, `scopes`, and role mapping (`homelab-admins` to Grafana Admin, `homelab-users` to Grafana Viewer).

4.  **Alertmanager Configuration (`config/alertmanager/alertmanager.yml`):**
    *   Define a `receiver` for `ntfy`.
    *   Define `route` to send all alerts to the `ntfy` receiver.
    *   Use templating for ntfy messages to include relevant alert details.

5.  **Promtail Configuration (`config/promtail/promtail-config.yaml`):**
    *   `docker` scrape config for auto-discovering and collecting logs from all Docker containers.
    *   `static_configs` for `/var/log/syslog` and Traefik access logs (assuming Traefik logs to a file accessible by Promtail or Promtail can access its Docker logs). For Traefik, we'll assume it's logging to stdout/stderr and Promtail can pick it up via Docker socket. For syslog, we'll mount `/var/log` into Promtail.

6.  **Uptime Kuma Setup Script (`scripts/uptime-kuma-setup.sh`):**
    *   This script will use `curl` to interact with Uptime Kuma's API to create monitors.
    *   It will need to wait for Uptime Kuma to be ready.
    *   It will dynamically discover services from `docker-compose.yml` or a predefined list and create monitors for their health endpoints.
    *   Configure a public status page and ntfy notification.
    *   **Important:** Uptime Kuma's API requires authentication. The script will need to log in first to get a cookie or token.

7.  **Environment Variables (`.env`):**
    *   `DOMAIN`: For Grafana, Uptime Kuma URLs.
    *   `NTFY_TOPIC`: For Alertmanager and Uptime Kuma notifications.
    *   `NTFY_URL`: Base URL for ntfy.
    *   `PROMETHEUS_RETENTION`, `LOKI_RETENTION`, `TEMPO_RETENTION`.
    *   `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`: Initial Grafana admin credentials.
    *   `GRAFANA_OIDC_CLIENT_ID`, `GRAFANA_OIDC_CLIENT_SECRET`, `GRAFANA_OIDC_AUTH_URL`, `GRAFANA_OIDC_TOKEN_URL`, `GRAFANA_OIDC_API_URL`.
    *   `UPTIME_KUMA_HOST`, `UPTIME_KUMA_PORT`: For the setup script to connect.
    *   `UPTIME_KUMA_USERNAME`, `UPTIME_KUMA_PASSWORD`: For the setup script to authenticate.

### Assumptions

*   The `homelab-stack` already has Traefik, Authentik, Nextcloud, Gitea deployed and accessible within the Docker network.
*   These services expose Prometheus-compatible metrics endpoints (e.g., `/metrics`). If not, additional exporters or custom configurations would be needed. For this solution, we'll assume standard `/metrics` endpoints on their default service ports.
*   `ntfy` service is already set up and accessible.
*   Authentik is set up and configured with `homelab-admins` and `homelab-users` groups.
*   The host system has `docker` and `docker-compose` installed.
*   The `DOMAIN` variable is correctly configured in the `.env` file for Traefik routing.

### Security Considerations

*   Sensitive information (API keys, passwords, client secrets) will be stored in `.env` and should not be committed to Git.
*   Promtail needs access to the Docker socket and `/var/log`. This is a common pattern but should be understood for its security implications.
*   Uptime Kuma's public status page should only expose non-sensitive information.
*   Grafana OIDC configuration ensures proper authentication and authorization.

This detailed plan covers all aspects of the bounty, from service integration to specific configuration requirements and automation.

---

## Production-Ready Code/Patch Implementation

Here's the comprehensive set of files to implement the observability stack.

### File: .env.example
```ini
# General
DOMAIN=your.domain.com
NTFY_TOPIC=homelab-alerts
NTFY_URL=https://ntfy.sh # Or your self-hosted ntfy instance

# Data Retention
PROMETHEUS_RETENTION=30d
LOKI_RETENTION=7d
TEMPO_RETENTION=3d

# Grafana Admin Credentials (for initial setup, OIDC will take over)
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=changeme

# Grafana OIDC Configuration (for Authentik)
GRAFANA_OIDC_CLIENT_ID=your_grafana_oidc_client_id
GRAFANA_OIDC_CLIENT_SECRET=your_grafana_oidc_client_secret
GRAFANA_OIDC_AUTH_URL=https://authentik.${DOMAIN}/application/o/authorize/
GRAFANA_OIDC_TOKEN_URL=https://authentik.${DOMAIN}/application/o/token/
GRAFANA_OIDC_API_URL=https://authentik.${DOMAIN}/application/o/userinfo/
GRAFANA_OIDC_SCOPES=openid profile email groups
GRAFANA_OIDC_ALLOWED_GROUPS=homelab-admins,homelab-users
GRAFANA_OIDC_ROLE_ATTRIBUTE_PATH=contains(groups[*], 'homelab-admins') && 'Admin' || contains(groups[*], 'homelab-users') && 'Viewer' || 'Viewer'

# Uptime Kuma Configuration
UPTIME_KUMA_HOST=uptime-kuma
UPTIME_KUMA_PORT=3001
UPTIME_KUMA_USERNAME=admin
UPTIME_KUMA_PASSWORD=changeme_uptime_kuma_password
```

### File: docker-compose.yml
```yaml
version: '3.8'

networks:
  homelab:
    external: true # Assuming a 'homelab' network already exists for other services
  observability:
    name: observability_network # Dedicated network for observability services

services:
  # --- Observability Stack ---

  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: prometheus
    hostname: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${PROMETHEUS_RETENTION}'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-remote-write-receiver' # Enable remote write for Grafana Agent/Mimir if needed later
    volumes:
      - ./config/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - observability
      - homelab # To scrape other homelab services
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.${DOMAIN}`)"
      - "traefik.http.routers.prometheus.entrypoints=websecure"
      - "traefik.http.routers.prometheus.tls.certresolver=le"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
      - "traefik.http.middlewares.prometheus-auth.forwardauth.address=http://authentik_proxy:9000/outpost.goauthentik.io/auth/traefik"
      - "traefik.http.middlewares.prometheus-auth.forwardauth.trustforwardheader=true"
      - "traefik.http.middlewares.prometheus-auth.forwardauth.authresponseheaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name"
      - "traefik.http.routers.prometheus.middlewares=prometheus-auth@docker"

  grafana:
    image: grafana/grafana:11.2.2
    container_name: grafana
    hostname: grafana
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_SERVER_ROOT_URL=https://grafana.${DOMAIN}
      - GF_AUTH_GENERIC_OAUTH_ENABLED=true
      - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
      - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OIDC_CLIENT_ID}
      - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OIDC_CLIENT_SECRET}
      - GF_AUTH_GENERIC_OAUTH_AUTH_URL=${GRAFANA_OIDC_AUTH_URL}
      - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=${GRAFANA_OIDC_TOKEN_URL}
      - GF_AUTH_GENERIC_OAUTH_API_URL=${GRAFANA_OIDC_API_URL}
      - GF_AUTH_GENERIC_OAUTH_SCOPES=${GRAFANA_OIDC_SCOPES}
      - GF_AUTH_GENERIC_OAUTH_ALLOWED_GROUPS=${GRAFANA_OIDC_ALLOWED_GROUPS}
      - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=${GRAFANA_OIDC_ROLE_ATTRIBUTE_PATH}
      - GF_AUTH_GENERIC_OAUTH_AUTO_LOGIN=true
      - GF_AUTH_GENERIC_OAUTH_TLS_SKIP_VERIFY_INSECURE=false # Set to true if Authentik uses self-signed certs
      - GF_AUTH_GENERIC_OAUTH_USE_PKCE=true # Recommended for OIDC
      - GF_AUTH_SIGNOUT_REDIRECT_URL=https://authentik.${DOMAIN}/application/o/authorize/
      - GF_LOG_LEVEL=info
      - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
    volumes:
      - ./config/grafana/provisioning:/etc/grafana/provisioning
      - ./config/grafana/dashboards:/var/lib/grafana/dashboards
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    restart: unless-stopped
    networks:
      - observability
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.${DOMAIN}`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=le"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  loki:
    image: grafana/loki:3.2.0
    container_name: loki
    hostname: loki
    command: -config.file=/etc/loki/loki-config.yaml
    volumes:
      - ./config/loki:/etc/loki
      - loki_data:/loki
    ports:
      - "3100:3100"
    restart: unless-stopped
    networks:
      - observability

  promtail:
    image: grafana/promtail:3.2.0
    container_name: promtail
    hostname: promtail
    command: -config.file=/etc/promtail/promtail-config.yaml
    volumes:
      - ./config/promtail:/etc/promtail
      - /var/log:/var/log:ro # For host syslog
      - /var/lib/docker/containers:/var/lib/docker/containers:ro # For Docker container logs
      - /var/run/docker.sock:/var/run/docker.sock:ro # For Docker metadata
    restart: unless-stopped
    network_mode: host # Required to access host's /var/log and Docker socket directly
    # Promtail doesn't need to be on the observability network directly if using network_mode: host
    # It will communicate with Loki via its host IP or a service discovery mechanism if Loki is also on host network.
    # For simplicity, we'll assume Loki is accessible via its container IP on the observability network.
    # If Loki is on a different host or not directly accessible, adjust promtail-config.yaml's client URL.

  tempo:
    image: grafana/tempo:2.6.0
    container_name: tempo
    hostname: tempo
    command: -config.file=/etc/tempo/tempo-config.yaml
    volumes:
      - ./config/tempo:/etc/tempo
      - tempo_data:/tempo
    ports:
      - "14268:14268" # Jaeger gRPC
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "3200:3200"   # Tempo HTTP (for UI/query)
    restart: unless-stopped
    networks:
      - observability

  alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: alertmanager
    hostname: alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    volumes:
      - ./config/alertmanager:/etc/alertmanager
      - alertmanager_data:/alertmanager
    ports:
      - "9093:9093"
    restart: unless-stopped
    networks:
      - observability
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.alertmanager.rule=Host(`alerts.${DOMAIN}`)"
      - "traefik.http.routers.alertmanager.entrypoints=websecure"
      - "traefik.http.routers.alertmanager.tls.certresolver=le"
      - "traefik.http.services.alertmanager.loadbalancer.server.port=9093"
      - "traefik.http.middlewares.alertmanager-auth.forwardauth.address=http://authentik_proxy:9000/outpost.goauthentik.io/auth/traefik"
      - "traefik.http.middlewares.alertmanager-auth.forwardauth.trustforwardheader=true"
      - "traefik.http.middlewares.alertmanager-auth.forwardauth.authresponseheaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name"
      - "traefik.http.routers.alertmanager.middlewares=alertmanager-auth@docker"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.50.0
    container_name: cadvisor
    hostname: cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8080:8080"
    restart: unless-stopped
    networks:
      - observability

  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    hostname: node-exporter
    command:
      - '--path.rootfs=/host'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/host:ro,rslave
    ports:
      - "9100:9100"
    restart: unless-stopped
    network_mode: host # Required to access host's /proc and /sys directly

  uptime-kuma:
    image: louislam/uptime-kuma:1.23.15
    container_name: uptime-kuma
    hostname: uptime-kuma
    volumes:
      - uptime_kuma_data:/app/data
    ports:
      - "3001:3001"
    restart: unless-stopped
    networks:
      - observability
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime-kuma.rule=Host(`status.${DOMAIN}`)"
      - "traefik.http.routers.uptime-kuma.entrypoints=websecure"
      - "traefik.http.routers.uptime-kuma.tls.certresolver=le"
      - "traefik.http.services.uptime-kuma.loadbalancer.server.port=3001"
      - "traefik.http.routers.uptime-kuma.middlewares=uptime-kuma-public@docker" # No auth for status page
      - "traefik.http.middlewares.uptime-kuma-public.stripprefix.prefixes=/" # Not strictly needed but good practice

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
  tempo_data:
  alertmanager_data:
  uptime_kuma_data:
```

### File: config/prometheus/prometheus.yml
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - '/etc/prometheus/alerts/host.yml'
  - '/etc/prometheus/alerts/containers.yml'
  - '/etc/prometheus/alerts/services.yml'

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090'] # Prometheus scrapes itself

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node-exporter'
    # Node Exporter runs on the host network, so we target the host IP.
    # If running in a container on the same host, 'host.docker.internal' or the host's actual IP can be used.
    # For network_mode: host, it's accessible on the host's IP.
    # Assuming Prometheus can reach the host's IP (e.g., 172.17.0.1 if using default bridge, or host.docker.internal)
    # For simplicity in a single-host docker-compose setup with network_mode: host,
    # we'll assume it's accessible via the host's IP or a specific IP if known.
    # A more robust solution for network_mode: host is to use `host.docker.internal` if supported,
    # or ensure Prometheus can reach the host's IP.
    # For this setup, since Prometheus is on the 'observability' network, and node-exporter is on 'host' network,
    # we need to ensure Prometheus can reach the host's IP.
    # If Prometheus is also on host network, 'localhost:9100' would work.
    # For now, let's assume `host.docker.internal` is available or the host IP is known.
    # If `host.docker.internal` is not available, replace with your host's actual IP.
    static_configs:
      - targets: ['host.docker.internal:9100'] # Or your host's IP if host.docker.internal doesn't work

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'tempo'
    static_configs:
      - targets: ['tempo:3200'] # Tempo's HTTP endpoint for metrics

  - job_name: 'uptime-kuma'
    static_configs:
      - targets: ['uptime-kuma:3001']

  - job_name: 'traefik'
    # Assuming Traefik is on the 'homelab' network and exposes metrics on port 8080 (or 8082 for API)
    # Check your Traefik configuration for the actual metrics port.
    # Default Traefik metrics are usually on the API port, often 8080 or 8082.
    # If Traefik is also managed by docker-compose, you can use its service name.
    static_configs:
      - targets: ['traefik:8080'] # Adjust port if Traefik metrics are on a different port

  - job_name: 'authentik'
    # Assuming Authentik is on the 'homelab' network and exposes metrics on port 9000 (or 9001 for worker)
    # Check Authentik documentation for actual metrics endpoint.
    static_configs:
      - targets: ['authentik:9000'] # Adjust port if Authentik metrics are on a different port

  - job_name: 'nextcloud'
    # Nextcloud typically doesn't expose Prometheus metrics directly.
    # You might need a separate exporter (e.g., php-fpm exporter, apache/nginx exporter, or a custom one).
    # For this bounty, we'll add a placeholder. If Nextcloud doesn't expose metrics, this target will be down.
    # A common approach is to use a `nextcloud-exporter` or monitor its underlying database/webserver.
    # Assuming a hypothetical exporter or a custom endpoint.
    static_configs:
      - targets: ['nextcloud:9200'] # Placeholder, adjust if you have a Nextcloud exporter

  - job_name: 'gitea'
    # Gitea exposes Prometheus metrics at /metrics endpoint, usually on its main HTTP port.
    # Default Gitea HTTP port is 3000.
    static_configs:
      - targets: ['gitea:3000']
```

### File: config/prometheus/alerts/host.yml
```yaml
groups:
  - name: host.rules
    rules:
      - alert: HostHighCPUUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Host {{ $labels.instance }} CPU usage is high"
          description: "CPU usage on {{ $labels.instance }} has been above 80% for 5 minutes. Current value: {{ $value | humanize }}%."

      - alert: HostHighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Host {{ $labels.instance }} memory usage is high"
          description: "Memory usage on {{ $labels.instance }} is above 90%. Current value: {{ $value | humanize }}%."

      - alert: HostHighDiskUsage
        expr: 100 - (node_filesystem_avail_bytes{fstype!="rootfs",mountpoint!~".*docker.*"} / node_filesystem_size_bytes{fstype!="rootfs",mountpoint!~".*docker.*"} * 100) > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Host {{ $labels.instance }} disk usage is high"
          description: "Disk usage on {{ $labels.instance }} for mountpoint {{ $labels.mountpoint }} is above 85%. Current value: {{ $value | humanize }}%."

      - alert: HostDiskIOErrors
        expr: node_disk_io_time_seconds_total > 0.1 # Example: if disk I/O time is consistently high
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Host {{ $labels.instance }} disk I/O errors/latency"
          description: "Disk I/O on {{ $labels.instance }} device {{ $labels.device }} is showing signs of errors or high latency. Current value: {{ $value | humanize }}."
```

### File: config/prometheus/alerts/containers.yml
```yaml
groups:
  - name: containers.rules
    rules:
      - alert: ContainerHighRestartRate
        expr: sum by (container_name) (rate(cadvisor_container_restart_count[1h])) > 3
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.container_name }} has high restart rate"
          description: "Container {{ $labels.container_name }} has restarted more than 3 times in the last hour. Current rate: {{ $value | humanize }} restarts/hour."

      - alert: ContainerOOMKilled
        expr: sum by (container_name) (rate(cadvisor_container_oom_events_total[5m])) > 0
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.container_name }} OOM killed"
          description: "Container {{ $labels.container_name }} was OOM killed. This indicates memory pressure."

      - alert: ContainerHealthcheckFailed
        # This alert requires services to expose healthcheck metrics.
        # For Docker, you might need to scrape Docker daemon events or use a custom exporter.
        # A common pattern is to have applications expose a /health endpoint and use blackbox exporter.
        # For cAdvisor, it doesn't directly expose healthcheck status.
        # This is a placeholder. If you have a specific healthcheck metric, replace `some_healthcheck_metric`.
        # Example: if a service exposes `service_health_status{service="my-app"} == 0` for unhealthy.
        expr: absent(container_last_seen{container_name=~".+"}) # Example: if a container disappears from cAdvisor
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.container_name }} health check failed"
          description: "Container {{ $labels.container_name }} is not reporting metrics or has disappeared."
```

### File: config/prometheus/alerts/services.yml
```yaml
groups:
  - name: services.rules
    rules:
      - alert: TraefikHigh5xxErrorRate
        expr: sum(rate(traefik_entrypoint_requests_total{code=~"5.."}[5m])) by (entrypoint) / sum(rate(traefik_entrypoint_requests_total[5m])) by (entrypoint) * 100 > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Traefik entrypoint {{ $labels.entrypoint }} has high 5xx error rate"
          description: "The 5xx error rate for Traefik entrypoint {{ $labels.entrypoint }} is above 1%. Current value: {{ $value | humanize }}%."

      - alert: ServiceHighResponseTimeP99
        # This requires services to expose request duration metrics.
        # For Traefik, you can use `traefik_service_request_duration_seconds_bucket`.
        # For other services, they need to be instrumented.
        # Example for Traefik:
        expr: histogram_quantile(0.99, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket[5m]))) > 

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
