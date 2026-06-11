 ```diff
--- /dev/null
+++ b/config/alertmanager/alertmanager.yml
@@ -0,0 +1,24 @@
+global:
+  resolve_timeout: 5m
+
+route:
+  group_by: ['alertname', 'severity']
+  group_wait: 30s
+  group_interval: 5m
+  repeat_interval: 4h
+  receiver: 'ntfy'
+  routes:
+    - match:
+        severity: critical
+      receiver: 'ntfy'
+      continue: true
+
+receivers:
+  - name: 'ntfy'
+    webhook_configs:
+      - url: 'http://ntfy:80/homelab-alerts'
+        send_resolved: true
+        http_config:
+          headers:
+            Title: 'Homelab Alert'
+            Priority: 'urgent'
+
+inhibit_rules: []
+
--- /dev/null
+++ b/config/grafana/dashboards/.gitkeep
@@ -0,0 +1 @@
+
--- /dev/null
+++ b/config/grafana/provisioning/dashboards/dashboards.yml
@@ -0,0 +1,12 @@
+apiVersion: 1
+
+providers:
+  - name: 'default'
+    orgId: 1
+    folder: ''
+    type: file
+    disableDeletion: false
+    editable: true
+    updateIntervalSeconds: 10
+    allowUiUpdates: true
+    options:
+      path: /var/lib/grafana/dashboards
+
--- /dev/null
+++ b/config/grafana/provisioning/datasources/datasources.yml
@@ -0,0 +1,41 @@
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
+  - name: Alertmanager
+    type: alertmanager
+    access: proxy
+    url: http://alertmanager:9093
+    editable: false
+    jsonData:
+      implementation: prometheus
+
+  - name: Uptime Kuma
+    type: uptime-kuma
+    access: proxy
+    url: http://uptime-kuma:3001
+    editable: false
+
+  - name: Jaeger
+    type: jaeger
+    access: proxy
+    url: http://tempo:3200
+    editable: false
+
--- /dev/null
+++ b/config/loki/loki-config.yml
@@ -0,0 +1,50 @@
+auth_enabled: false
+
+server:
+  http_listen_port: 3100
+  grpc_listen_port: 9096
+
+common:
+  path_prefix: /tmp/loki
+  storage:
+    filesystem:
+      chunks_directory: /tmp/loki/chunks
+      rules_directory: /tmp/loki/rules
+  replication_factor: 1
+  ring:
+    instance_addr: 127.0.0.1
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
+limits_config:
+  retention_period: 168h
+  allow_structured_metadata: true
+
+chunk_store_config:
+  max_look_back_period: 168h
+
+table_manager:
+  retention_deletes_enabled: true
+  retention_period: 168h
+
+ruler:
+  storage:
+    type: local
+    local:
+      directory: /tmp/loki/rules
+  rule_path: /tmp/loki/rules
+  alertmanager_url: http://alertmanager:9093
+  ring:
+    kvstore:
+      store: inmemory
+  enable_api: true
+
+analytics:
+  reporting_enabled: false
+
--- /dev/null
+++ config/prometheus/alerts/containers.yml
@@ -0,0 +1,29 @@
+groups:
+  - name: containers
+    rules:
+      - alert: ContainerRestartedTooOften
+        expr: rate(docker_container_restarts_total[1h]) > 3
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} restarted too often"
+          description: "Container {{ $labels.name }} has restarted more than 3 times in the last hour."
+
+      - alert: ContainerOOMKilled
+        expr: docker_container_oom_events_total > 0
+        for: 0m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Container {{ $labels.name }} OOM killed"
+          description: "Container {{ $labels.name }} was killed due to out of memory."
+
+      - alert: ContainerHealthCheckFailed
+        expr: docker_container_health_status{status!="healthy"} == 1
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} health check failed"
+          description: "Container {{ $labels.name }} has been unhealthy for more than 5 minutes."
+
--- /dev/null
+++ b/config/prometheus/alerts/host.yml
@@ -0,0 +1,33 @@
+groups:
+  - name: host
+    rules:
+      - alert: HostHighCPUUsage
+        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "High CPU usage on {{ $labels.instance }}"
+          description: "CPU usage is above 80% for more than 5 minutes."
+
+      - alert: HostHighMemoryUsage
+        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
+        for: 0m
+        labels:
+          severity: critical
+        annotations:
+          summary: "High memory