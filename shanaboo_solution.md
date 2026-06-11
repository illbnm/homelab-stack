 ```diff
--- a/.env.example
+++ b/.env.example
@@ -0,0 +0,0 @@
+# ============================================
+# 🏠 HomeLab Stack - Environment Configuration
+# ============================================
+
+# Domain
+DOMAIN=example.com
+
+# Data paths
+DATA_PATH=./data
+
+# Monitoring Retention
+PROMETHEUS_RETENTION=30d
+LOKI_RETENTION=7d
+TEMPO_RETENTION=3d
+
+# ntfy notifications
+NTFY_URL=https://ntfy.sh
+NTFY_TOPIC=homelab-alerts
+
+# Authentik OIDC
+AUTHENTIK_CLIENT_ID=grafana
+AUTHENTIK_CLIENT_SECRET=change-me
+AUTHENTIK_URL=https://authentik.${DOMAIN}
+
+# Uptime Kuma
+UPTIME_KUMA_STATUS_DOMAIN=status.${DOMAIN}
+
+# Grafana
+GF_SECURITY_ADMIN_USER=admin
+GF_SECURITY_ADMIN_PASSWORD=admin
+
--- /dev/null
+++ b/config/alertmanager/alertmanager.yml
@@ -0,0 +1,0 @@
+route:
+  group_by: ['alertname', 'severity']
+  group_wait: 10s
+  group_interval: 10s
+  repeat_interval: 1h
+  receiver: 'ntfy'
+
+receivers:
+  - name: 'ntfy'
+    webhook_configs:
+      - url: '${NTFY_URL}/${NTFY_TOPIC}'
+        send_resolved: true
+        http_config:
+          headers:
+            Title: 'Alertmanager'
+            Priority: 'urgent'
+
+inhibit_rules:
+  - source_match:
+      severity: 'critical'
+    target_match:
+      severity: 'warning'
+    equal: ['alertname', 'instance']
+
--- /dev/null
+++ b/config/grafana/provisioning/dashboards/dashboards.yml
@@ -0,0 +1,0 @@
+apiVersion: 1
+
+providers:
+  - name: 'default'
+    orgId: 1
+    folder: ''
+    type: file
+    disableDeletion: false
+    editable: true
+    updateIntervalSeconds: 30
+    allowUiUpdates: true
+    options:
+      path: /etc/grafana/provisioning/dashboards
+
--- /dev/null
+++ b/config/grafana/provisioning/datasources/datasources.yml
@@ -0,0 +1,0 @@
+apiVersion: 1
+
+datasources:
+  - name: Prometheus
+    type: prometheus
+    access: proxy
+    url: http://prometheus:9090
+    isDefault: true
+    editable: false
+
+  - name: Loki
+    type: loki
+    access: proxy
+    url: http://loki:3100
+    editable: false
+
+  - name: Tempo
+    type: tempo
+    access: proxy
+    url: http://tempo:3200
+    editable: false
+
--- /dev/null
+++ b/config/loki/loki-config.yml
@@ -0,0 +1,0 @@
+auth_enabled: false
+
+server:
+  http_listen_port: 3100
+  grpc_listen_port: 9096
+
+common:
+  path_prefix: /loki
+  storage:
+    filesystem:
+      chunks_directory: /loki/chunks
+      rules_directory: /loki/rules
+  replication_factor: 1
+  ring:
+    kvstore:
+      store: inmemory
+
+schema_config:
+  configs:
+    - from: 2020-10-24
+      store: boltdb-shipper
+      object_store: filesystem
+      schema: v11
+      index:
+        prefix: index_
+        period: 24h
+
+storage_config:
+  filesystem:
+    directory: /loki/index
+
+compactor:
+  working_directory: /loki/compactor
+  retention_enabled: true
+  retention_delete_delay: 2h
+  retention_delete_worker_count: 150
+
+limits_config:
+  retention_period: 7d
+
+table_manager:
+  retention_deletes_enabled: true
+  retention_period: 7d
+
+chunk_store_config:
+  max_look_back_period: 7d
+
--- /dev/null
+++ b/config/prometheus/alerts/containers.yml
@@ -0,0 +1,0 @@
+groups:
+  - name: containers
+    rules:
+      - alert: ContainerRestartedTooOften
+        expr: rate(engine_daemon_container_restarts_total[1h]) > 3
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} restarted too often"
+          description: "Container {{ $labels.name }} has restarted more than 3 times in the last hour."
+
+      - alert: ContainerOOMKilled
+        expr: container_oom_events_total > 0
+        for: 0m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Container {{ $labels.name }} was OOM killed"
+          description: "Container {{ $labels.name }} was killed due to out of memory."
+
+      - alert: ContainerHealthCheckFailed
+        expr: container_health_status != 0
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} health check failed"
+          description: "Container {{ $labels.name }} has failed its health check for more than 5 minutes."
+
--- /dev/null
+++ b/config/prometheus/alerts/host.yml
@@ -0,0 +1 {{
+  - name: host
+    rules:
+      - alert: HostCPUHigh
+        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Host CPU usage is above 80% (instance {{ $labels.instance }})"
+          description: "CPU usage on {{ $labels.instance }} has been above 80% for more than 5 minutes."
+
+      - alert: HostMemoryHigh
+        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
+        for: 0m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Host memory usage is above 90% (instance {{ $