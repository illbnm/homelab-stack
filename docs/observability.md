# 可观测性栈 (Observability Stack)

完整实现 Metrics / Logs / Traces / Alerting / Uptime 监控。

## 📦 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | 指标采集 |
| Grafana | `grafana/grafana:11.2.2` | 3000 | 可视化面板 |
| Loki | `grafana/loki:3.2.0` | 3100 | 日志聚合 |
| Promtail | `grafana/promtail:3.2.0` | 9080 | 日志采集 Agent |
| Tempo | `grafana/tempo:2.6.0` | 3200 | 分布式链路追踪 |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | 告警路由 |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | 容器指标 |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | 主机指标 |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | 服务可用性监控 |
| Grafana OnCall | `grafana/oncall:v1.9.22` | 8080 | 值班告警管理 |

## 🚀 部署步骤

### 1. 准备环境变量

```bash
cd stacks/monitoring
cp .env.example .env
# 编辑 .env 文件，设置必要的变量
```

### 2. 启动服务

```bash
docker compose up -d
```

### 3. 验证服务状态

```bash
# 检查所有容器运行状态
docker compose ps

# 查看 Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# 查看 Grafana 健康状态
curl http://localhost:3000/api/health
```

## 📊 Grafana Dashboard

预置 Dashboard 已自动加载：

| Dashboard | UID | 说明 |
|-----------|-----|------|
| Node Exporter Full | `node-exporter-full` | 主机资源监控 |
| Docker Container & Host Metrics | `docker-container-metrics` | 容器资源监控 |
| Traefik Official | `traefik-official` | 反向代理监控 |
| Loki Dashboard | `loki-dashboard` | 日志聚合视图 |
| Uptime Kuma | `uptime-kuma` | 服务可用性 |
| Logs | `logs` | 日志探索快捷方式 |

访问地址：`https://grafana.${DOMAIN}`

## 🔔 告警规则

### 主机告警 (`host.yml`)
- CPU > 80% 持续 5 分钟
- 内存 > 90%
- 磁盘 > 85%
- 磁盘 IO 异常

### 容器告警 (`containers.yml`)
- 容器重启次数 > 3 次/小时
- 容器 OOM 被杀
- 容器健康检查失败

### 服务告警 (`services.yml`)
- Traefik 5xx 错误率 > 1%
- 服务响应时间 P99 > 2s

所有告警路由到 Alertmanager → ntfy 推送。

## 📝 Loki 日志采集

Promtail 自动采集：
- ✅ 所有 Docker 容器日志（自动发现）
- ✅ 系统日志 `/var/log/*.log`
- ✅ Traefik access log

在 Grafana 中访问 Logs Dashboard 快速查询：`/d/logs/logs`

## ⏱️ Uptime Kuma 配置

### 自动创建监控项

```bash
# 设置 API Key（在 Uptime Kuma 设置页面生成）
export UPTIME_KUMA_API_KEY="your-api-key"

# 运行配置脚本
./scripts/uptime-kuma-setup.sh
```

### 状态页

公开访问地址：`https://status.${DOMAIN}`

## 🔗 数据源集成

### Grafana 数据源
- **Prometheus** (默认) - 指标查询
- **Loki** - 日志查询
- **Tempo** - 链路追踪

### Prometheus 采集目标
- cadvisor - 容器资源
- node-exporter - 主机资源
- traefik - 反代指标
- authentik - SSO 指标
- nextcloud - 存储指标
- gitea - 代码托管指标
- prometheus - 自监控
- loki - 日志服务
- alertmanager - 告警服务
- tempo - 追踪服务
- uptime-kuma - 可用性监控

## 📦 数据保留策略

```bash
# .env 配置
PROMETHEUS_RETENTION=30d  # 指标保留 30 天
LOKI_RETENTION=7d         # 日志保留 7 天
TEMPO_RETENTION=3d        # 追踪保留 3 天
```

## 🔐 Authentik 集成

### Grafana OAuth 配置

1. 在 Authentik 创建 OAuth2 Provider
2. 设置重定向 URL: `https://grafana.${DOMAIN}/login/generic_oauth`
3. 在 Grafana .env 中设置:
   ```bash
   GRAFANA_OAUTH_CLIENT_ID=xxx
   GRAFANA_OAUTH_CLIENT_SECRET=xxx
   ```

### 权限映射

- `homelab-admins` 组 → Grafana Admin
- `homelab-users` 组 → Grafana Viewer

## ✅ 验收清单

- [ ] Grafana 可访问，所有预置 Dashboard 自动加载
- [ ] Prometheus targets 页面所有 job 显示 UP
- [ ] Loki 中可查询到任意容器日志
- [ ] 手动触发 CPU 告警（`stress --cpu 4`），ntfy 在 5 分钟内收到告警
- [ ] Uptime Kuma 状态页可公开访问
- [ ] `uptime-kuma-setup.sh` 自动创建所有服务监控项
- [ ] Grafana 可用 Authentik 账号登录，权限正确
- [ ] cAdvisor 容器资源面板正常显示

## 🛠️ 故障排查

### Prometheus Targets 显示 DOWN

```bash
# 检查网络连接
docker network inspect monitoring

# 查看 Prometheus 配置
docker exec prometheus cat /etc/prometheus/prometheus.yml

# 重新加载配置
curl -X POST http://localhost:9090/-/reload
```

### Loki 无法查询日志

```bash
# 检查 Promtail 状态
docker logs promtail

# 验证日志文件权限
ls -la /var/log
```

### Grafana Dashboard 未加载

```bash
# 检查 Dashboard 文件
ls -la config/grafana/dashboards/

# 查看 Grafana 日志
docker logs grafana
```

## 📚 相关文档

- [Prometheus 配置](../../config/prometheus/prometheus.yml)
- [Grafana 配置](../../config/grafana/)
- [Loki 配置](../../config/loki/)
- [告警规则](../../config/prometheus/alerts/)
