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
--- /dev/null
+++ b/config/grafana/provisioning/dashboards/dashboard.yml
@@ -0,0 +1,14 @@
+apiVersion: 1
+
+providers:
+  - name: 'default'
+    orgId: 1
+    folder: ''
+    folderUid: ''
+    type: file
+    disableDeletion: false
+    updateIntervalSeconds: 10
+    allowUiUpdates: false
+    options:
+      path: /var/lib/grafana/dashboards
+      foldersFromFilesStructure: true
+
--- /dev/null
+++ b/config/grafana/provisioning/datasources/datasource.yml
@@ -0,0 +1,48 @@
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
+    jsonData:
+      maxLines: 1000
+      derivedFields:
+        - name: TraceID
+          matcherRegex: '"trace_id":"(\w+)"'
+          url: '${__value.raw}'
+          datasourceUid: tempo
+
+  - name: Tempo
+    type: tempo
+    access: proxy
+    url: http://tempo:3200
+    editable: false
+    jsonData:
+      tracesToLogs:
+        datasourceUid: loki
+        tags: ['pod', 'container']
+        mappedTags: [{ key: 'service.name', value: 'service' }]
+        mapTagNamesEnabled: false
+        spanStartTimeShift: '1h'
+        spanEndTimeShift: '1h'
+        filterByTraceID: false
+        filterBySpanID: false
+      tracesToMetrics:
+        datasourceUid: prometheus
+      serviceMap:
+        datasourceUid: prometheus
+
+  - name: Alertmanager
+    type: alertmanager
+    access: proxy
+    url: http://alertmanager:9093
+    editable: false
+    jsonData:
+      implementation: prometheus
+
--- /dev/null
+++ b/config/loki/loki.yml
@@ -0,0 +1,50 @@
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
+query_range:
+  results_cache:
+    cache:
+      embedded_cache:
+        enabled: true
+        max_size_mb: 100
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
+  ingestion_rate_mb: 16
+  ingestion_burst_size_mb: 32
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
+      directory: /loki/rules
+
--- /dev/null
+++ b/config/prometheus/alerts/containers.yml
@@ -0,0 +1,31 @@
+groups:
+  - name: containers
+    rules:
+      - alert: ContainerRestarted
+        expr: |
+          increase(container_last_seen{name!="",name!="/"}[1h]) > 3
+        for: 0m
+        labels:
+        severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} restarted multiple times"
+          description: "Container {{ $labels.name }} on {{ $labels.instance }} has restarted more than 3 times in the last hour."
+
+      - alert: ContainerOOMKilled
+        expr: |
+          container_oom_events_total{name!="",name!="/"} > 0
+        for: 0m
+        labels:
+        severity: critical
+        annotations:
+          summary: "Container {{ $labels.name }} OOM killed"
+          description: "Container {{ $labels.name }} on {{ $labels.instance }} was killed due to out of memory."
+
+      - alert: ContainerUnhealthy
+        expr: |
+          container_health_status{name!="",name!="/"} == 0
+        for: 5m
+        labels:
+        severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} health check failed"
+          description: "Container {{ $labels.name }} on {{ $labels.instance }} has failed health check for more than 5 minutes."
+
--- /dev/null
+++ b/config/prometheus/alerts/host.yml
@@ -0,0 +1,35 @@
+groups:
+  - name: host
+    rules:
+      - alert: HostHighCpuUsage
+        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
+        for: 5m
+        labels:
+        severity: warning
+        annotations:
+          summary: "Host high CPU usage (instance {{ $labels.instance }})"
+          description: "CPU usage is above 80