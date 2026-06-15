 ```diff
--- a/.env.example
+++ b/.env.example
@@ -0,0 +0,0 @@
+# Base domain for all services
+DOMAIN=example.com
+
+# Data retention policies
+PROMETHEUS_RETENTION=30d
+LOKI_RETENTION=7d
+TEMPO_RETENTION=3d
+
+# Ntfy notification topic for alerts
+NTFY_TOPIC=homelab-alerts
+
+# Authentik OIDC for Grafana
+GRAFANA_OAUTH_CLIENT_ID=
+GRAFANA_OAUTH_CLIENT_SECRET=
+GRAFANA_OAUTH_AUTH_URL=https://authentik.${DOMAIN}/application/o/authorize/
+GRAFANA_OAUTH_TOKEN_URL=https://authentik.${DOMAIN}/application/o/token/
+GRAFANA_OAUTH_API_URL=https://authentik.${DOMAIN}/application/o/userinfo/
+
--- /dev/null
+++ b/config/alertmanager/alertmanager.yml
@@ -0,0 +1,0 @@
+route:
+  receiver: 'default'
+  group_by: ['alertname', 'severity']
+  group_wait: 10s
+  group_interval: 10s
+  repeat_interval: 1h
+
+receivers:
+  - name: 'default'
+    webhook_configs:
+      - url: 'http://ntfy:80/${NTFY_TOPIC}'
+        send_resolved: true
+        title: '{{ template "default.title" . }}'
+        message: '{{ template "default.message" . }}'
+
+templates:
+  - '/etc/alertmanager/*.tmpl'
+
--- /dev/null
+++ b/config/alertmanager/default.tmpl
@@ -0,0 +1,0 @@
+{{ define "default.title" }}{{ .Status | title }}: {{ .GroupLabels.alertname }}{{ end }}
+{{ define "default.message" }}{{ range .Alerts }}{{ .Annotations.summary }}
+{{ .Annotations.description }}{{ end }}{{ end }}
+
--- /dev/null
+++ b/config/grafana/dashboards/.gitkeep
@@ -0,0 +1,0 @@
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
+    options:
+      path: /var/lib/grafana/dashboards
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
+
+  - name: Loki
+    type: loki
+    access: proxy
+    url: http://loki:3100
+
+  - name: Tempo
+    type: tempo
+    access: proxy
+    url: http://tempo:3200
+
+  - name: Alertmanager
+    type: alertmanager
+    access: proxy
+    url: http://alertmanager:9093
+    jsonData:
+      implementation: prometheus
+
--- /dev/null
+++ b/config/loki/loki.yml
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
+      store: tsdb
+      object_store: filesystem
+      schema: v13
+      index:
+        prefix: index_
+        period: 24h
+
+limits_config:
+  retention_period: ${LOKI_RETENTION}
+
+compactor:
+  working_directory: /loki/compactor
+  retention_enabled: true
+  retention_delete_delay: 2h
+  retention_delete_worker_count: 150
+
+table_manager:
+  retention_deletes_enabled: true
+  retention_period: ${LOKI_RETENTION}
+
+analytics:
+  reporting_enabled: false
+
--- /dev/null
+++ b/config/prometheus/alerts/containers.yml
@@ -0,0 +1,0 @@
+groups:
+  - name: containers
+    rules:
+      - alert: ContainerRestartedTooOften
+        expr: rate(container_last_seen{name!=""}[1h]) > 3
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
+          summary: "Container {{ $labels.name }} OOM killed"
+          description: "Container {{ $labels.name }} was killed due to out of memory."
+
+      - alert: ContainerHealthCheckFailed
+        expr: container_health_status{Monitoring == "true"} != 0
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} health check failed"
+          description: "Container {{ $labels.name }} health check has been failing for more than 5 minutes."
+
--- /dev/null
+++ b/config/prometheus/alerts/host.yml
@@ -0,0 +1,0 @@
+groups:
+  - name: host
+    rules:
+      - alert: HostHighCpuUsage
+        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Host high CPU usage (instance {{ $labels.instance }})"
+          description: "CPU usage is above 80% for more than 5 minutes."
+
+      - alert: HostHighMemoryUsage
+        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 