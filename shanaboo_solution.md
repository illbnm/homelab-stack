 ```diff
--- /dev/null
+++ b/config/alertmanager/alertmanager.yml
@@ -0,0 +1,28 @@
+global:
+  resolve_timeout: 5m
+  smtp_smarthost: ''
+  smtp_from: ''
+
+route:
+  receiver: 'ntfy'
+  group_by: ['alertname', 'severity', 'instance']
+  group_wait: 30s
+  group_interval: 5m
+  repeat_interval: 4h
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
+templates:
+  - '/etc/alertmanager/templates/*.tmpl'
--- /dev/null
+++ b/config/grafana/dashboards/.gitkeep
@@ -0,0 +1 @@
+
--- /dev/null
+++ 	config/grafana/provisioning/dashboards/dashboards.yml
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
+    editable: true
+    updateIntervalSeconds: 30
+    allowUiUpdates: true
+    options:
+      path: /var/lib/grafana/dashboards
+      foldersFromFilesStructure: true
--- /dev/null
+++ 	config/grafana/provisioning/datasources/datasources.yml
@@ -0,0 +1,46 @@
+apiVersion: 1
+
+datasources:
+  - name: Prometheus
+    type: prometheus
+    access: proxy
+    url: http://prometheus:9090
+    isDefault: true
+    editable: false
+    jsonData:
+      timeInterval: 5s
+      httpMethod: POST
+      manageAlerts: true
+      alertmanagerUid: alertmanager
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
+          matcherRegex: '"trace_id":"([^"]+)"'
+          url: 'http://tempo:16686/trace/$${__value.raw}'
+
+  - name: Tempo
+    type: tempo
+    access: proxy
+    url: http://tempo:3200
+    editable: false
+    jsonData:
+      tracesToLogs:
+        datasourceUid: loki
+        tags: ['job', 'instance']
+        spanStartTimeShift: '-1h'
+        spanEndTimeShift: '1h'
+      tracesToMetrics:
+        datasourceUid: prometheus
+        tags: ['job', 'instance']
+      serviceMap:
+        datasourceUid: prometheus
+
+  - name: Alertmanager
+    type: alertmanager
+    access: proxy
+    url: http://alertmanager:9093
+    uid: alertmanager
+    editable: false
--- /dev/null
+++ 	config/loki/loki-config.yml
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
+  retention_period: ${LOKI_RETENTION:-7d}
+  reject_old_samples: true
+  reject_old_samples_max_age: 168h
+
+chunk_store_config:
+  max_look_back_period: 0s
+
+table_manager:
+  retention_deletes_enabled: true
+  retention_period: ${LOKI_RETENTION:-7d}
+
+compactor:
+  working_directory: /loki/compactor
+  retention_enabled: true
+  retention_delete_delay: 2h
+  retention_delete_worker_count: 150
+  compaction_interval: 10m
+
+ruler:
+  storage:
+    type: local
+    local:
+      directory: /loki/rules
+  rule_path: /loki/rules-temp
+  alertmanager_url: http://alertmanager:9093
--- /dev/null
+++ 	config/prometheus/alerts/containers.yml
@@ -0,0 +1,35 @@
+groups:
+  - name: containers
+    rules:
+      - alert: ContainerRestartedFrequently
+        expr: |
+          rate(docker_container_restart_count[1h]) > 3
+        for: 5m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} restarted frequently"
+          description: "Container {{ $labels.name }} has restarted more than 3 times in the last hour."
+
+      - alert: ContainerOOMKilled
+        expr: |
+          (
+            time() - container_last_seen{image!=""}
+          ) < 60
+          and on(instance, name)
+          (
+            container_oom_events_total > 0
+          )
+        for: 0m
+        labels:
+          severity: critical
+        annotations:
+          summary: "Container {{ $labels.name }} OOM killed"
+          description: "Container {{ $labels.name }} was killed due to out of memory."
+
+      - alert: ContainerHealthCheckFailed
+        expr: |
+          docker_container_health_status{status="unhealthy"} == 1
+        for: 2m
+        labels:
+          severity: warning
+        annotations:
+          summary: "Container {{ $labels.name }} health check failed"
+          description: "Container {{ $labels.name }} is reporting unhealthy status."
--- /dev/null
+++ 	config/prometheus/al