# Observability Stack — Prometheus + Grafana + Loki

基于 Prometheus、Grafana、Loki 的可观测性基础设施，提供指标收集、日志聚合和可视化监控。

## 架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HomeLab Services                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                   │
│   │  Services   │    │  Services   │    │  Services   │                   │
│   │  (metrics)  │    │   (logs)    │    │             │                   │
│   └──────┬──────┘    └──────┬──────┘    │             │                   │
│          │                  │           │             │                   │
│          ▼                  ▼           │             │                   │
│   ┌─────────────────────────────────────┴─────────────┐                   │
│   │              promtail (log collector)              │                   │
│   └──────────────────────┬────────────────────────────┘                   │
│                          │                                                 │
│   ┌──────────────────────┼──────────────────────────────────────────────┐ │
│   │                      ▼                                               │ │
│   │  ┌─────────┐    ┌─────────┐    ┌─────────────┐    ┌─────────────┐  │ │
│   │  │Prometheus│    │  Loki   │    │ Alertmanager│    │  cAdvisor   │  │ │
│   │  │ :9090   │    │ :3100   │    │   :9093     │    │  :8080      │  │ │
│   │  └────┬────┘    └────┬────┘    └──────┬──────┘    └──────┬──────┘  │ │
│   │       │              │                 │                 │         │ │
│   │       └──────────────┴─────────────────┴─────────────────┘         │ │
│   │                              │                                     │ │
│   │                              ▼                                     │ │
│   │                    ┌─────────────────┐                             │ │
│   │                    │    Grafana      │                             │ │
│   │                    │    :3000        │                             │ │
│   │                    │ (OIDC Auth)     │                             │ │
│   │                    └─────────────────┘                             │ │
│   │                                                                      │ │
│   └──────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                       Traefik (443)
                       authentik ForwardAuth
```

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | 指标收集与存储 |
| Grafana | `grafana/grafana:11.2.0` | 3000 | 指标可视化面板 |
| Loki | `grafana/loki:3.2.0` | 3100 | 日志聚合 |
| Promtail | `grafana/promtail:3.2.0` | — | 日志收集代理 |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | 告警管理 |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.49.1` | 8080 | 容器指标 |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | 主机指标 |

## 前提条件

- Base stack 已运行（`stacks/base/` — Traefik + proxy network）
- SSO stack 已运行（`stacks/sso/` — Authentik）
- 域名 DNS 已指向服务器
- 端口 80 + 443 开放

## 快速开始

### 1. 复制并填写环境变量

```bash
cd stacks/monitoring
cp .env.example .env
nano .env  # 填写所有必需值
```

### 2. 生成密钥

```bash
# 生成 Grafana 管理员密码
export GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 16)

# 从 SSO stack 获取 OIDC 凭据（如果已运行 setup-authentik.sh）
source ../sso/.env

# 写入 .env
sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" .env
sed -i "s|^GRAFANA_OAUTH_CLIENT_ID=.*|GRAFANA_OAUTH_CLIENT_ID=$GRAFANA_OAUTH_CLIENT_ID|" .env
sed -i "s|^GRAFANA_OAUTH_CLIENT_SECRET=.*|GRAFANA_OAUTH_CLIENT_SECRET=$GRAFANA_OAUTH_CLIENT_SECRET|" .env
sed -i "s|^AUTHENTIK_DOMAIN=.*|AUTHENTIK_DOMAIN=$AUTHENTIK_DOMAIN|" .env
sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" .env
```

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 验证服务

```bash
# 检查所有容器状态
docker compose ps

# 验证 Prometheus
curl -sf http://localhost:9090/-/healthy && echo "Prometheus OK"

# 验证 Grafana
curl -sf http://localhost:3000/api/health && echo "Grafana OK"

# 验证 Loki
curl -sf http://localhost:3100/ready && echo "Loki OK"
```

### 5. 访问 Grafana

1. 打开 `https://grafana.yourdomain.com`
2. 使用 Authentik 账号登录（或本地 admin 账号）
3. 默认角色：OIDC 用户自动分配为 `Viewer`

## 环境变量

| 变量 | 必需 | 说明 |
|------|------|------|
| `DOMAIN` | YES | 根域名，例如 `yourdomain.com` |
| `AUTHENTIK_DOMAIN` | YES | Authentik 域名，例如 `auth.yourdomain.com` |
| `GRAFANA_ADMIN_USER` | YES | Grafana 本地管理员用户名 |
| `GRAFANA_ADMIN_PASSWORD` | YES | Grafana 本地管理员密码 |
| `GRAFANA_OAUTH_CLIENT_ID` | YES | Authentik OAuth2 Client ID |
| `GRAFANA_OAUTH_CLIENT_SECRET` | YES | Authentik OAuth2 Client Secret |

### Grafana OIDC 属性映射

| 环境变量 | 说明 |
|----------|------|
| `GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH` | 基于用户组自动分配角色 |

角色映射规则：
- 包含 `Grafana Admins` 组 → `Admin`
- 包含 `Grafana Editors` 组 → `Editor`
- 其他用户 → `Viewer`

## 指标采集

### Prometheus 采集目标

| 目标 | 地址 | 用途 |
|------|------|------|
| Prometheus 自监控 | `http://localhost:9090` | 自身指标 |
| Node Exporter | `http://node-exporter:9100` | 主机 CPU/内存/磁盘/网络 |
| cAdvisor | `http://cadvisor:8080` | 容器资源使用 |
| Alertmanager | `http://alertmanager:9093` | 告警状态 |

### 查看采集目标

1. 访问 Grafana → **Status** → **Targets**
2. 或直接访问 `https://prometheus.yourdomain.com/targets`

## 日志采集

### Promtail 采集源

| 源 | 路径 | 说明 |
|----|------|------|
| Docker 容器日志 | `/var/lib/docker/containers` | 所有容器 stdout/stderr |
| 系统日志 | `/var/log` | 系统日志目录 |
| Docker socket | `/var/run/docker.sock` | 容器元数据 |

### 在 Grafana 中查看日志

1. 登录 Grafana
2. 左侧菜单 → **Explore**
3. 选择 **Loki** 数据源
4. 使用 LogQL 查询日志

示例查询：
```logql
# 查看所有日志
{job="promtail"}

# 查看特定容器日志
{container_name="grafana"}

# 错误日志
{job="promtail"} |= "error"

# 最近 5 分钟
{job="promtail"} | json | level="error" | __line__ > now - 5m
```

## 告警配置

### Alertmanager 告警渠道

默认配置文件 `config/alertmanager/alertmanager.yml` 未配置告警渠道（placeholder）。

添加告警接收者：

```yaml
# config/alertmanager/alertmanager.yml
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@yourdomain.com'
        send_resolved: true

  - name: 'webhook'
    webhook_configs:
      - url: 'http://your-webhook/alert'
```

### 创建 Prometheus 告警规则

在 `config/prometheus/rules/` 目录添加告警规则文件：

```yaml
# config/prometheus/rules/node-alerts.yml
groups:
  - name: node
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (node_memory_MemAvailableBytes / node_memory_MemTotalBytes) * 100 < 20
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
```

## Grafana 面板

### 预置面板

首次启动后，Grafana 会自动配置以下数据源：

| 数据源 | URL | 用途 |
|--------|-----|------|
| Prometheus | `http://prometheus:9090` | 指标查询 |
| Loki | `http://loki:3100` | 日志查询 |

### 导入社区面板

推荐面板 ID：

| 面板名称 | ID | 说明 |
|----------|-----|------|
| Docker and Kubernetes Dashboard | 179 | 容器/集群概览 |
| Node Exporter Full | 1860 | 主机详细指标 |
| Prometheus Stats | 2 | Prometheus 状态 |
| Loki Logs Dashboard | 15141 | 日志浏览 |

### 创建自定义面板

1. Grafana → **Dashboards** → **New Dashboard**
2. 添加 **Visualization**
3. 选择数据源（Prometheus 或 Loki）
4. 编写查询

Prometheus 示例：
```promql
# CPU 使用率
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 内存使用率
(1 - (node_memory_MemAvailableBytes / node_memory_MemTotalBytes)) * 100

# 容器 CPU
container_cpu_usage_seconds_total{container_name!=""}
```

## 验收清单

- [ ] Prometheus 可访问，采集所有服务指标
- [ ] Grafana 可通过 Authentik OIDC 登录
- [ ] Grafana 面板显示主机指标（Node Exporter）
- [ ] Grafana 面板显示容器指标（cAdvisor）
- [ ] Loki 收集所有容器日志
- [ ] Grafana Explore 可查询 Loki 日志
- [ ] Alertmanager 配置告警规则
- [ ] 告警可触发（邮件/webhook）
- [ ] Grafana 用户角色基于 Authentik 组自动分配
- [ ] 所有指标保留 30 天
- [ ] README 包含新服务接入监控的教程

## 新服务接入监控

### 步骤 1：添加 Prometheus 采集

如果服务暴露 `/metrics` 端点：

```yaml
# 在服务的 docker-compose.yml 中添加
labels:
  - "prometheus.job=${service_name}"
  - "prometheus.port=9090"
```

或在 `config/prometheus/prometheus.yml` 添加 scrape config：

```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:9090']
```

### 步骤 2：添加日志采集

Promtail 自动采集所有 Docker 容器日志。如需自定义：

```yaml
# config/loki/promtail-config.yml
scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          __path__: /var/log/syslog
```

### 步骤 3：创建 Grafana 面板

1. Grafana → **Dashboards** → **New Dashboard**
2. 选择 Prometheus 数据源
3. 添加查询并可视化

## 故障排查

| 症状 | 解决方案 |
|------|----------|
| Prometheus 无数据 | 检查 targets 状态，确认采集目标可达 |
| Grafana 登录失败 | 检查 `GRAFANA_OAUTH_CLIENT_ID` 和 `SECRET`，确认回调 URL 正确 |
| Loki 无日志 | 检查 Promtail 日志，确认 `/var/lib/docker/containers` 可访问 |
| 面板加载慢 | 减少查询时间范围，使用 Rate 函数替代原始 Counter |
| 告警未触发 | 检查 Alertmanager 配置，确认 receiver 正确 |

### 常用调试命令

```bash
# 查看 Prometheus 采集状态
curl http://localhost:9090/api/v1/targets | jq

# 查看 Loki 日志
curl -s "http://localhost:3100/loki/api/v1/query?query={job='promtail'}" | jq

# 查看 Alertmanager 状态
curl http://localhost:9093/api/v1/status | jq

# 查看 cAdvisor 指标
curl http://localhost:8080/metrics

# 查看 Node Exporter 指标
curl http://localhost:9100/metrics
```

## 国内镜像

如果 Docker Hub 访问困难，可在 `docker-compose.yml` 中使用镜像：

```yaml
# 添加镜像加速
image: docker.m.daocloud.io/prom/prometheus:v2.54.1
image: docker.m.daocloud.io/grafana/grafana:11.2.0
image: docker.m.daocloud.io/grafana/loki:3.2.0
```

## 参考链接

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/grafana/)
- [Loki 文档](https://grafana.com/docs/loki/)
- [cAdvisor 文档](https://github.com/google/cadvisor)
- [Node Exporter 文档](https://github.com/prometheus/node_exporter)
- [LogQL 查询示例](https://grafana.com/docs/loki/latest/logql/)

## 赏金信息

**金额**: $280 USDT  
**Issue**: [illbnm/homelab-stack #10](https://github.com/illbnm/homelab-stack/issues/10)