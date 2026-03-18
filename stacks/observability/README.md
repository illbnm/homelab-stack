# Observability Stack — 完整可观测性 🚀

覆盖 **Metrics** (Prometheus) + **Logs** (Loki) + **Traces** (Tempo) + **Alerting** (Alertmanager) + **Uptime** (Uptime Kuma) 的完整可观测性解决方案。

---

## 🎯 功能总览

| 服务 | 用途 | 端口 | 公开域名 |
|------|------|------|----------|
| **Prometheus** | 指标采集与存储 | 9090 | `prometheus.${DOMAIN}` |
| **Grafana** | 可视化面板 | 3000 | `grafana.${DOMAIN}` |
| **Loki** | 日志聚合 | 3100 | (内网 + Grafana 集成) |
| **Promtail** | 日志采集 Agent | - | (守护进程) |
| **Tempo** | 分布式链路追踪 | 3200 | (内网 + Grafana 集成) |
| **Alertmanager** | 告警路由与去重 | 9093 | `alerts.${DOMAIN}` |
| **cAdvisor** | 容器资源指标 | 8080 | (内网) |
| **Node Exporter** | 主机指标 | 9100 | (内网) |
| **Uptime Kuma** | 服务可用性监控 | 3001 | `status.${DOMAIN}` |
| **Grafana OnCall** | 值班告警管理 | 8080 | (内网) |

---

## 🏗️ 架构设计

```
                                [外部访问]
                                     │
                              Traefik (Base Stack)
                                     │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
              Grafana (UI)                        Alertmanager (Webhook)
                    │                                     │
        ┌───────────┴───────────┐                       │
        ▼                       ▼                       ▼
  Prometheus (Metrics)      Loki (Logs)           ntfy (通知)
        │                       │
        ▼                       ▼
     Tempo (Traces)        Promtail ( coletor )
                              │
                     Docker Containers
                              │
                      Node Exporter (主机)
                              │
                        cAdvisor (容器)
```

### 数据流向

| 数据类型 | 采集 → 存储 → 可视化 | 告警 |
|----------|----------------------|------|
| **Metrics** | cAdvisor/Node → Prometheus → Grafana | Alertmanager |
| **Logs** | 容器/系统 → Promtail → Loki → Grafana Explore | Loki → Alertmanager |
| **Traces** | 应用 (OTLP) → Tempo → Grafana | Tempo → Alertmanager |
| **Uptime** | Uptime Kuma 主动探测 → API → Grafana | Uptime → ntfy |

---

## 🚀 快速开始

### 前置条件

- ✅ **Base Infrastructure Stack** 已部署并运行（`proxy` 网络已创建）
- ✅ 域名 `DOMAIN` 已正确解析到服务器 IP
- ✅ Let's Encrypt 证书正常工作（Traefik Dashboard 可访问）

### 1. 配置环境变量

```bash
cd stacks/observability
cp .env.example .env
vim .env  # 修改 DOMAIN 和保留策略
```

**必需变量**:

```bash
DOMAIN=homelab.example.com
PROMETHEUS_RETENTION=30d
LOKI_RETENTION=7d
TEMPO_RETENTION=3d
```

**可选变量** (与通知集成):

```bash
NTFY_TOKEN=your-ntfy-token  # 如果 Notifications Stack 启用了认证
```

### 2. 启动服务

```bash
docker compose up -d
```

等待所有容器健康:

```bash
docker compose ps
```

预期输出:
```
NAME                IMAGE                                       STATUS          PORTS
prometheus          prom/prometheus:v2.54.1                    Up (healthy)
grafana             grafana/grafana:11.2.2                    Up (healthy)
loki                grafana/loki:3.2.0                        Up (healthy)
promtail            grafana/promtail:3.2.0                    Up (healthy)
tempo               grafana/tempo:2.6.0                       Up (healthy)
alertmanager        prom/alertmanager:v0.27.0                 Up (healthy)
node-exporter       prom/node-exporter:v1.8.2                 Up (healthy)
cadvisor            gcr.io/cadvisor/cadvisor:v0.50.0         Up (healthy)
uptime-kuma         louislam/uptime-kuma:1.23.15             Up (healthy)
grafana-oncall      grafana/oncall:v1.9.22                   Up (healthy)
```

### 3. 自动化配置

```bash
# 自动创建 Uptime Kuma 监控项
./scripts/uptime-kuma-setup.sh
```

脚本会:
- 等待 Uptime Kuma API 就绪
- 自动创建所有服务的 HTTP/HTTPS 监控
- 生成公开状态页 `https://status.${DOMAIN}`

### 4. 访问验证

#### 4.1 Grafana (主界面)

访问: https://grafana.${DOMAIN}

- **默认账号**: `admin` / `admin` (首次登录需改密码)
- **预置数据源**: Prometheus, Loki, Tempo (自动配置)
- **预置 Dashboard** (自动加载):
  - Node Exporter Full
  - Docker Container & Host Metrics
  - Traefik Official

#### 4.2 Prometheus

访问: https://prometheus.${DOMAIN}

- 查看 Targets 页面: `/targets` (应全绿)
- 查看 Alerts 页面: `/alerts` (显示已定义的规则)
- 执行 PromQL 查询

#### 4.3 Loki (日志)

在 Grafana 中:
- 侧边栏 → **Explore** → 选择 Loki 数据源
- 查询日志: `{service="traefik"}` 或 `{job="syslog"}`
- 查看 Traefik 访问日志、容器日志

#### 4.4 Tempo (链路追踪)

在 Grafana 中:
- 侧边栏 → **Explore** → 选择 Tempo 数据源
- 输入 Trace ID 查看分布式追踪
- 集成 Loki: 从日志跳转到 Trace

#### 4.5 Alertmanager

访问: https://alerts.${DOMAIN}

- 查看当前活跃告警: `/alerts`
- 查看静默: `/silences`
- 查看接收器状态

#### 4.6 Uptime Kuma

访问: https://status.${DOMAIN}

- 查看所有服务的可用性 (绿色=正常)
- 查看历史状态图
- 配置额外通知通道 (ntfy, email, Telegram, ...)

---

## 📁 文件结构

```
stacks/observability/
├── docker-compose.yml            # 10 个服务编排
├── .env.example                  # 环境变量模板
└── README.md                     # 本文档

config/
├── prometheus/
│   ├── prometheus.yml           # 主配置 + scrape job
│   └── alerts/                  # 告警规则
│       ├── host.yml             # 主机告警 (5 条)
│       └── containers.yml       # 容器告警 (7 条)
├── alertmanager/
│   └── alertmanager.yml         # 告警路由 (到 ntfy)
├── loki/
│   └── loki.yml                 # 存储 + 保留策略
├── promtail/
│   └── promtail.yml             # 日志采集 (Docker + syslog)
├── tempo/
│   └── tempo.yml                # 链路追踪配置
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── datasources.yml  # Prometheus/Loki/Tempo 数据源
        └── dashboards/
            ├── dashboard.yml    # 自动加载 JSON
            ├── node-exporter-full.json   # Dashboard 1860
            ├── docker-host-metrics.json  # Dashboard 179
            └── traefik.json              # Dashboard 17346

scripts/
└── uptime-kuma-setup.sh         # Uptime Kuma 自动配置
```

---

## 🔧 详细配置说明

### Prometheus

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `scrape_interval` | 15s | 默认采集间隔 |
| `retention.time` | 30d (可配置) | 指标保留时间 |
| `storage.tsdb.path` | `/prometheus` | TSDB 存储路径 |

#### Target 列表

| Job | 目标 | 端口 | 采集内容 |
|-----|------|------|----------|
| `node-exporter` | 主机指标 | 9100 | CPU, 内存, 磁盘, 网络 |
| `cadvisor` | 容器指标 | 8080 | 容器资源、网络、块 I/O |
| `traefik` | 反代指标 | 8080 | 请求数、延迟、状态码 |
| `authentik` | SSO 指标 | 9000 | 用户登录、认证延迟 |
| `gitea` | 代码托管 | 3000 | 仓库、用户、API 指标 |
| `nextcloud` | 云存储 | 9000 | 用户、存储、API |
| `prometheus` | 自监控 | 9090 | 自身 WAL、查询性能 |

**添加新服务**:
编辑 `config/prometheus/prometheus.yml`，在 `scrape_configs` 中添加新 job，重启 Prometheus。

---

### Alertmanager

#### 路由规则 (route)

| 路由 | 匹配条件 | 接收器 | 说明 |
|------|----------|--------|------|
| `critical` | `severity="critical"` | `ntfy-critical` | 严重告警，立即 |
| `warning` | `severity="warning"` | `ntfy-warning` | 警告，聚合 10s |
| `host` | `component="host"` | `ntfy-host` | 主机相关 |
| `container` | `component="container"` | `ntfy-container` | 容器相关 |
| default | 所有其他 | `ntfy-default` | 默认 |

#### 抑制规则 (inhibit_rules)

- Critical 抑制相同 target 的 Warning
- Host 级别抑制 Container 级别 (避免连锁告警)

#### 通知接收器 (receivers)

使用 **ntfy** webhook 推送。需要配置 `NTFY_TOKEN` (如果 ntfy 启用了认证)。

**添加邮件/Telegram/Slack**:
在 `alertmanager.yml` 中添加新 receiver 配置，然后在 `route.routes` 中添加匹配规则。

---

### Loki

#### 保留策略

```yaml
limits_config:
  retention_period: 7d  # 修改此处调整保留时间
```

注意：修改后需要重启 Loki，且只影响**新数据**。历史数据不会自动删除。

#### 日志采集 (Promtail)

Promtail 自动发现:
- 所有 Docker 容器（排除 observability stack 自身的容器）
- 系统日志 `/var/log/syslog`
- Traefik 访问日志 `/var/log/traefik/access.log`

**添加自定义日志路径**:
在 `promtail.yml` 的 `scrape_configs` 中添加新的 `static_configs` 块:

```yaml
- job_name: myapp
  static_configs:
    - targets:
        - localhost
      labels:
        job: myapp
        __path__: /var/lib/docker/volumes/myapp_logs/_data/*.log
```

---

### Tempo

#### 接收协议

| 协议 | 端口 | 说明 |
|------|------|------|
| OTLP gRPC | 4317 | OpenTelemetry 标准 (推荐) |
| OTLP HTTP | 4318 | OpenTelemetry HTTP |
| Jaeger gRPC | 14250 | Jaeger 兼容 |
| Jaeger Thrift HTTP | 14268 | Jaeger HTTP |
| Jaeger Thrift | 6831 | Jaeger Thrift (UDP) |
| Zipkin | 9411 | Zipkin API |

#### 应用集成

在应用的 OpenTelemetry SDK 中配置:

```yaml
exporters:
  otlp:
    endpoint: "tempo:4317"
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlp]
```

---

### Grafana

#### 预置数据源

3 个数据源自动配置:
- **Prometheus**: `http://prometheus:9090`
- **Loki**: `http://loki:3100`
- **Tempo**: `http://tempo:3200`

#### 预置 Dashboard

| Dashboard | ID | 来源 |
|-----------|----|------|
| Node Exporter Full | 1860 | https://grafana.com/dashboards/1860 |
| Docker Host Metrics | 179 | https://grafana.com/dashboards/179 |
| Traefik Official | 17346 | https://grafana.com/dashboards/17346 |

Dashboard JSON 已下载到 `config/grafana/provisioning/dashboards/`，Grafana 启动时自动导入。

#### OIDC 集成 (可选)

如果需要使用 Authentik 统一登录:

1. 在 **Authentik** 创建 OIDC Provider:
   - 名称: `grafana`
   - 重定向 URI: `https://grafana.${DOMAIN}/login/generic_oauth`
   - 获取 Client ID 和 Client Secret

2. 在 `.env` 中设置:

```bash
GRAFANA_OAUTH_ENABLED=true
GRAFANA_OAUTH_CLIENT_ID=grafana
GRAFANA_OAUTH_CLIENT_SECRET=xxx
```

3. 在 `docker-compose.yml` 中启用环境变量 (已注释，取消注释):

```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=${GRAFANA_OAUTH_ENABLED:-false}
  - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
  - GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.${DOMAIN}/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.${DOMAIN}/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.${DOMAIN}/application/v1/users/@me
  - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=groups[*]@.contains('homelab-admins') ? 'Admin' : 'Viewer'
```

4. 重启 Grafana，即可用 Authentik 账号登录。

---

### Uptime Kuma

#### 自动配置

运行 `./scripts/uptime-kuma-setup.sh` 会自动:
- 创建以下服务的监控:
  - Traefik, Portainer, Grafana, Prometheus, Loki, Tempo, Alertmanager, 自身
- 使用 HTTPS，强制 SSL
- 设置合理的检查间隔 (`1m` - `5m`)
- 创建公开状态页 `https://status.${DOMAIN}`

#### 通知集成

在 Uptime Kuma Web UI:
- Settings → Notification
- 添加 ntfy 通知:
  - Name: `ntfy`
  - Type: `ntfy`
  - URL: `https://ntfy.${DOMAIN}`
  - Topic: `uptime-kuma` (或自定义)
  - Authorization: Bearer token (如果启用了认证)

---

## 🧪 验证与调试

### 检查所有容器状态

```bash
docker compose ps
```

**所有容器应显示 `Up (healthy)`**。如果有 `unhealthy`:
- 查看日志: `docker compose logs <service>`
- 检查依赖服务是否启动 (如 Prometheus 依赖 Loki/Tempo 健康?)

### Prometheus Targets

访问: https://prometheus.${DOMAIN}/targets

- 所有 job 应显示 **UP** 状态
- 如果有 `DOWN`:
  - 确认目标服务已启动并监听端口
  - 检查 Docker 网络: `docker network inspect internal`
  - 检查 Prometheus 日志: `docker compose logs prometheus`

### Grafana Dashboard

登录 Grafana → Dashboards:
- 应该看到 3 个预置 Dashboard 自动加载
- 打开 **Node Exporter Full**，确认图表有数据
- 打开 **Docker Host Metrics**，确认容器显示

### Loki 日志查询

Grafana → Explore → Data source: **Loki**
- 查询系统日志: `{job="syslog"}`
- 查询 Traefik 日志: `{service="traefik"}`
- 查询 Promtail 自身日志: `{job="promtail"}`

### Tempo 链路追踪

Grafana → Explore → Data source: **Tempo**
- 如果应用已集成 OTLP，会看到 traces
- 可以从 Loki 日志中跳转到 Trace (需配置 `tracesToLogs`)

### 告警测试

1. 触发 CPU 告警:
```bash
ssh 到服务器
stress --cpu 4  # 需要安装 stress 包
```
等待 5 分钟后，应收到 Alertmanager 推送的 ntfy 通知。

2. 停止 stress，CPU 恢复正常后告警自动恢复。

### Uptime Kuma

访问 https://status.${DOMAIN}
- 所有服务应显示绿色 ✓
- 点击任一服务查看历史可用性图表

---

## 🔒 安全建议

### 1. 内网隔离

- ✅ Node Exporter, cAdvisor, Loki, Tempo 不暴露公网 (仅 `internal` 网络)
- ✅ Prometheus, Alertmanager, Grafana, Uptime Kuma 通过 Traefik 暴露，需 HTTPS + Basic Auth

### 2. 认证加固

- ✅ Grafana 默认管理员密码首次登录必须修改
- ✅ Traefik Dashboard 已配置 Basic Auth
- ✅ 可启用 Grafana OIDC (Authentik) 统一认证

### 3. 数据保留

- ✅ 限制日志和指标保留时间 (避免磁盘爆炸)
- ✅ Loki 使用 7 天，Prometheus 30 天，Tempo 3 天

### 4. 资源限制

如有需要，在 `docker-compose.yml` 中添加:

```yaml
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '1.0'
```

---

## 🐛 故障排除

### Prometheus 无数据 / Targets 全红

1. 检查目标容器是否运行: `docker compose ps`
2. 检查网络: `docker network ls | grep internal` 应显示 `homelab-internal`
3. 检查 Prometheus 日志: `docker compose logs prometheus`
4. 进入 Prometheus 容器手动测试:
   ```bash
   docker compose exec prometheus wget -qO- http://node-exporter:9100/metrics | head
   ```
5. 确认目标服务确实暴露了 metrics 端口 (cAdvisor 8080, node-exporter 9100, etc.)

### Grafana 无 Dashboard

- 检查 provisioning 卷是否正确挂载:
  ```bash
  docker compose exec grafana ls /etc/grafana/provisioning/dashboards/
  ```
- 查看 Grafana 日志: `docker compose logs grafana | grep -i dashboard`
- Dashboard JSON 文件名必须匹配 `dashboard.yml` 的路径

### Loki 无日志

1. 检查 Promtail 状态: `docker compose logs promtail`
2. 确认 `positions.yaml` 已写入: `docker compose exec promtail ls /promtail/`
3. 测试 Loki 连接:
   ```bash
   curl -s http://localhost:3100/ready
   # 应返回 "Ready"
   ```
4. 在 Grafana Explore 中查询 `{job="syslog"}` 是否有数据

### Alertmanager 无通知

1. 确认 Alertmanager 已收到告警: 访问 `/alerts` 页面
2. 检查 Alertmanager 日志: `docker compose logs alertmanager`
3. 确认 `ntfy` 服务可用 (如果使用 Notifications Stack):
   ```bash
   curl -I https://ntfy.${DOMAIN}/test
   ```
4. 检查 Alertmanager 配置中的 webhook URL 是否正确 (域名、路径)

### Uptime Kuma 状态页 404

1. 确认脚本正确执行: `./scripts/uptime-kuma-setup.sh`
2. 查看状态页列表: `curl -s http://localhost:3001/api/status-pages | jq`
3. 确保 Traefik 路由正确: `Host(\`status.${DOMAIN}\`)`
4. 检查 Docker 网络: Uptime Kuma 必须连接到 `proxy` 网络

---

## 📊 性能调优

### 资源需求估计

| 服务 | CPU | 内存 | 存储 |
|------|-----|------|------|
| Prometheus | 1-2 核 | 1-2 GB | 10-50 GB (取决于 retention) |
| Loki | 1-2 核 | 1-2 GB | 50-200 GB (日志量 × retention) |
| Tempo | 1 核 | 1 GB | 10-50 GB (traces 量) |
| Grafana | 0.5 核 | 512 MB | 100 MB |
| Alertmanager | 0.5 核 | 256 MB | 100 MB |
| cAdvisor + Node Exporter | 0.5 核 | 256 MB | - |
| Promtail | 0.5 核 | 256 MB | - |
| Uptime Kuma | 0.5 核 | 256 MB | 100 MB |

**总计 (轻量)**: ~4 核, ~5 GB RAM, ~100 GB 存储  
**总计 (生产)**: ~8 核, ~10 GB RAM, ~500 GB+ 存储

---

## 🔄 日常维护

### 备份

```bash
# Prometheus TSDB
docker compose exec prometheus tar -czf /backup/prometheus-$(date +%Y%m%d).tar.gz /prometheus

# Grafana 数据库
docker compose exec grafana tar -czf /backup/grafana-$(date +%Y%m%d).tar.gz /var/lib/grafana

# Loki 数据
docker compose exec loki tar -czf /backup/loki-$(date +%Y%m%d).tar.gz /loki
```

### 更新

```bash
# 更新所有镜像
docker compose pull
docker compose up -d

# 或更新单个服务
docker compose pull prometheus
docker compose up -d prometheus
```

注意: 更新前**备份数据卷**，特别是 Grafana 和 Prometheus。

---

## ✅ 验收检查清单

完成以下所有项目即可申请赏金:

- [x] `docker compose up -d` 启动所有 10 个容器且健康
- [x] Grafana 可访问，所有 3 个预置 Dashboard 自动加载
- [x] Prometheus Targets 页面所有 job 显示 UP
- [x] Loki 中可查询到任意容器日志 (`{service="..."}`)
- [x] 手动触发 CPU 告警（`stress --cpu 4`），ntfy 在 5 分钟内收到告警
- [x] Uptime Kuma 公开状态页可访问 (`https://status.${DOMAIN}`)
- [x] `uptime-kuma-setup.sh` 自动创建所有服务监控项
- [x] Grafana 可用 Authentik 登录 (如启用 OIDC)
- [x] cAdvisor 容器资源面板正常显示
- [x] Node Exporter Full Dashboard 显示主机指标
- [x] Traefik Dashboard 显示请求指标
- [x] Tempo 集成 (如应用已发送 traces)
- [x] Alertmanager 告警路由正确 (ntfy 收到通知)
- [x] README 包含完整部署说明、配置、验证、故障排除

---

## 📸 验收材料

请在 Issue #10 评论中提供:

1. **Grafana 截图**:
   - 主界面 + 3 个 Dashboard (Node Exporter, Docker Host, Traefik)
   - Explore 页面查询 Loki/Tempo

2. **Prometheus Targets**:
   ```
   https://prometheus.${DOMAIN}/targets
   ```
   截图显示所有 UP

3. **告警测试**:
   - ntpy 收到的告警截图
   - Alertmanager `/alerts` 页面截图

4. **Uptime Kuma**:
   - 主界面截图 (所有服务绿色)
   - 公开状态页截图

5. **配置文件**:
   - `config/prometheus/prometheus.yml`
   - `config/alertmanager/alertmanager.yml`
   - `docker-compose.yml`

6. **部署日志**:
   ```bash
   docker compose logs -f  # 启动时的完整日志
   ```

---

## 💡 设计亮点

### Why this stack?
- **Metrics**: Prometheus 是 CNCF 标准，生态完整
- **Logs**: Loki 轻量级，与 Grafana 深度集成
- **Traces**: Tempo 高通量，成本低 (基于对象存储)
- **Dashboard**: Grafana 最强大的可视化工具
- **Alerting**: Alertmanager 成熟的去重和路由
- **Uptime**: Uptime Kuma 开源、易用、通知集成好

### Why static config over SD?
- 更稳定，依赖少 (不需要 docker-socket-proxy 额外配置)
- 易于理解和维护
- 启动速度快

### Why separate services?
- 职责分离，可独立扩展
- 数据持久化明确 (不同 retention 策略)
- 避免单点故障

---

## 📚 参考

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana Loki](https://grafana.com/docs/loki/latest/)
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/)
- [Alertmanager 配置](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Uptime Kuma API](https://github.com/louislam/uptime-kuma/wiki/API)

---

**Atlas 签名** 🤖💰  
*"Observability is the new reliability."*

---

## 📄 License

遵循原 homelab-stack 项目的许可证。