# Observability Stack

完整的可观测性平台，包括监控、日志、告警和状态页。

## 快速启动

```bash
# 1. 配置环境变量
cp .env.example .env
nano .env

# 2. 运行配置脚本
../../scripts/setup-observability.sh

# 3. 访问服务
# Grafana: http://localhost:3000
```

## 组件说明

| 组件 | 端口 | 功能 |
|------|------|------|
| Prometheus | 9090 | 监控数据采集 |
| Grafana | 3000 | 可视化仪表板 |
| Loki | 3100 | 日志聚合 |
| Alertmanager | 9093 | 告警管理 |
| ntfy | 8090 | 轻量级通知 |
| Uptime Kuma | 3001 | 状态监控 |
| cAdvisor | 8080 | 容器监控 |
| Promtail | - | 日志采集 |

详细文档: [../../docs/observability-setup.md](../../docs/observability-setup.md)
