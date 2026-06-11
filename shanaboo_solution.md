 ```diff
--- a/.env.example
+++ b/.env.example
@@ -45,6 +45,12 @@
 # Monitoring
 # -----------------------------------------------------------------------------
 PROMETHEUS_RETENTION=30d
+LOKI_RETENTION=7d
+TEMPO_RETENTION=3d
+GRAFANA_ADMIN_USER=admin
+GRAFANA_ADMIN_PASSWORD=changeme
+ALERTMANAGER_NTFY_URL=https://ntfy.sh/homelab-alerts
+UPTIME_KUMA_NTFY_URL=https://ntfy.sh/homelab-uptime
 
 # -----------------------------------------------------------------------------
 # Notifications
--- a/config/prometheus/prometheus.yml
+++ b/config/prometheus/prometheus.yml
@@ -0,0 +1,73 @@
+global:
+  scrape_interval: 15s
+  evaluation_interval: 15s
+  external_labels:
+    monitor: 'homelab'
+
+alerting:
+  alertmanagers:
+    - static_configs:
+        - targets: ['alertmanager:9093']
+
+rule_files:
+  - /etc/prometheus/alerts/*.yml
+
+scrape_configs:
+  - job_name: 'prometheus'
+    static_configs:
+      - targets: ['localhost:9090']
+
+  - job_name: 'cadvisor'
+    static_configs:
+      - targets: ['cadvisor:8080']
+
+  - job_name: 'node-exporter'
+    static_configs:
+      - targets: ['node-exporter:9100']
+
+  - job_name: 'traefik'
+    static_configs:
+      - targets: ['traefik:8080']
+
+  - job_name: 'authentik'
+    static_configs:
+      - targets: ['authentik:9300']
+
+  - job_name: 'nextcloud'
+    static_configs:
+      - targets: ['nextcloud:9205']
+
+  - job_name: 'gitea'
+    static_configs:
+      - targets: ['gitea:3000']
+    metrics_path: /metrics
--- a/config/prometheus/alerts/host.yml
+++ b/config/prometheus/alerts/host.yml
@@ -0,0 +1,47 @@
+groups:
+  - name: host
+    rules:
+      - alert: HostHighCpuUsage
+        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Host CPU usage is above 80%"
+          description: "CPU usage on {{ $labels.instance }} has been above 80% for more than 5 minutes."
+
+      - alert: HostHighMemoryUsage
+        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
+        for: 5m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Host memory usage is above 90%"
+          description: "Memory usage on {{ $labels.instance }} has been above 90% for more than 5 minutes."
+
+      - alert: HostHighDiskUsage
+        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 15
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Host disk usage is above 85%"
+          description: "Disk usage on {{ $labels.instance }} has been above 85% for more than 5 minutes."
+
+      - alert: HostUnusualDiskIO
+        expr: rate(node_disk_io_time_seconds_total[5m]) > 0.5
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Host unusual disk IO"
+          description: "Unusual disk IO detected on {{ $labels.instance }}."
--- a/config/prometheus/alerts/containers.yml
+++ b/config/prometheus/alerts/containers.yml
@@ -0,0 +1,32 @@
+groups:
+  - name: containers
+    rules:
+      - alert: ContainerRestartedTooManyTimes
+        expr: rate(container_last_seen[1h]) > 3
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container restarted too many times"
+          description: "Container {{ $labels.name }} has restarted more than 3 times in the last hour."
+
+      - alert: ContainerOOMKilled
+        expr: container_oom_events_total > 0
+        for: 0m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Container OOM killed"
+          description: "Container {{ $labels.name }} was killed due to out of memory."
+
+      - alert: ContainerHealthCheckFailed
+        expr: container_health_status{status="unhealthy"} == 1
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container health check failed"
+          description: "Container {{ $labels.name }} health check has failed for more than 5 minutes."
--- a/config/prometheus/alerts/services.yml
+++ b/config/prometheus/alerts/services.yml
@@ -0,0 +1,21 @@
+groups:
+  - name: services
+    rules:
+      - alert: TraefikHigh5xxErrorRate
+        expr: |
+          sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) /
+          sum(rate(traefik_service_requests_total[5m])) > 0.01
+        for: 5m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Traefik 5xx error rate is high"
+          description: "Traefik 5xx error rate is above 1% for more than 5 minutes."
+
+      - alert: ServiceHighResponseTime
+        expr: histogram_quantile(0.99, sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le, service)) > 2
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Service response time P99 is high"
+          description: "Service {{ $labels.service }} P99 response time is above 2 seconds."
--- a/config/grafana/provisioning/dashboards/dashboard.yml
+++ b/config/grafana/provisioning/dashboards/dashboard.yml
@@ -0,0 +1,12 @@
+apiVersion: 1
+
+providers:
+  - name: 'default'
+    orgId: 1
+    folder: ''
+    type: file
+    disableDeletion