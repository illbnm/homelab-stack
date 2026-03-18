# Observability Stack

可观测性栈，提供指标收集、日志聚合、告警管理和站点可用性监控功能。

## 📋 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Prometheus | prom/prometheus:v2.54.1 | 指标收集和存储 |
| Grafana | grafana/grafana:11.2.0 | 指标可视化和仪表盘 |
| Loki | grafana/loki:3.2.0 | 日志聚合存储 |
| Promtail | grafana/promtail:3.2.0 | 日志收集代理 |
| Alertmanager | prom/alertmanager:v0.27.0 | 告警路由和管理 |
| cAdvisor | gcr.io/cadvisor/cadvisor:v0.49.1 | 容器资源指标 |
| Node Exporter | prom/node-exporter:v1.8.2 | 宿主机指标收集 |
| Uptime Kuma | louislam/uptime-kuma:1.23.13 | 服务可用性监控 |

## 🚀 前置准备

### 1. 依赖 Base 栈

本栈依赖 Base 栈提供的反向代理和网络，请先完成 [Base 栈](../base/README.md) 的部署。

确保已创建共享网络：

```bash
docker network create proxy
```

### 2. 配置 DNS

将以下域名解析到你的 homelab 服务器 IP：
- `grafana.${DOMAIN}` - Grafana 仪表盘
- `prometheus.${DOMAIN}` - Prometheus
- `status.${DOMAIN}` - Uptime Kuma 状态页

### 3. 创建配置和环境

```bash
# 复制环境变量文件
cp stacks/monitoring/.env.example stacks/monitoring/.env
nano stacks/monitoring/.env  # 编辑配置
```

## ⚙️ 配置说明

### 预配置内容

本栈已经包含基础配置文件：
- Prometheus 配置已包含 Node Exporter 和 cAdvisor 监控任务
- Loki 配置使用单节点运行模式
- Alertmanager 基础路由配置已创建
- Promtail 已配置收集 Docker 容器日志

### 认证配置

Grafana 支持两种认证方式：

1. **默认用户名密码认证**
   - 默认用户名：`admin`
   - 密码在 `.env` 中配置
   - 适合个人使用

2. **OAuth 认证（使用 Authentik）**
   - 在 Authentik 创建 Grafana OAuth 应用
   - 在 `.env` 填入客户端 ID 和密钥
   - 开启后自动根据用户组分配角色：
     - `Grafana Admins` → Admin
     - `Grafana Editors` → Editor
     - 其他 → Viewer

### 存储保留策略

- **Prometheus:** 默认保留 30 天指标数据
- **Loki:** 默认保留 7 天日志数据
- 可通过修改 command 参数调整保留时间

### Uptime Kuma

- 自托管网站和服务可用性监控
- 支持多种通知方式（Email、Telegram、Slack 等）
- 支持状态页分享
- 数据存储在 `uptime-kuma-data` volume

## 🚀 启动服务

```bash
cd stacks/monitoring
docker compose up -d
```

检查容器状态：

```bash
docker compose ps
```

Prometheus, Grafana, Loki, Uptime Kuma 应该都显示 `Up (healthy)`。

## 📝 首次使用

### 1. 访问 Grafana

打开 `https://grafana.${DOMAIN}`，使用 `.env` 中配置的用户名密码登录。

### 2. 添加数据源

Grafana 已经通过 provisioning 自动配置了 Prometheus 和 Loki 数据源，开箱即用：
- Prometheus: `http://prometheus:9090`
- Loki: `http://loki:3100`

### 3. 导入仪表盘

推荐导入以下社区仪表盘：
- **Node Exporter Full:** ID `1860` - 宿主机监控
- **Docker and cAdvisor:** ID `14825` - 容器监控
- **Loki:** ID `13186` - 日志浏览

### 4. 配置 Uptime Kuma

打开 `https://status.${DOMAIN}`，创建管理员账号，然后添加需要监控的服务。

### 5. 配置告警

1. 在 `config/prometheus/rules/` 添加告警规则文件
2. 在 `config/alertmanager/alertmanager.yml` 配置告警接收方式（Email, Telegram, Slack 等）
3. 重新加载 Prometheus 配置：

```bash
curl -X POST http://localhost:9090/-/reload
```

## ✅ 验收检查

1. ✅ 所有容器状态正常，健康检查通过
2. ✅ 能访问 `grafana.${DOMAIN}` 并登录
3. ✅ Grafana 能正常查询 Prometheus 指标
4. ✅ Grafana 能正常查询 Loki 日志
5. ✅ 能访问 `status.${DOMAIN}` 并添加监控项

## 🔧 使用指南

### 添加新的监控目标

在 Prometheus 的 `config/prometheus/prometheus.yml` 中添加新的 scrape 配置，然后执行：

```bash
curl -X POST http://prometheus:9090/-/reload
```

### 添加日志收集

Promtail 已经默认收集所有 Docker 容器日志，无需额外配置。如果需要收集宿主机日志，修改 `config/loki/promtail-config.yml`。

### 邮件告警配置示例

在 `config/alertmanager/alertmanager.yml` 中添加：

```yaml
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'admin-email'

receivers:
- name: 'admin-email'
  email_configs:
  - to: 'your-email@example.com'
    send_resolved: true
    from: 'alertmanager@example.com'
    smarthost: 'smtp.example.com:587'
    auth_username: 'your-username'
    auth_password: 'your-password'
```

### 查看已收集日志

在 Grafana 中打开 Explore，选择 Loki 数据源，即可查询和查看所有容器日志。

## 📝 文件结构

```
stacks/monitoring/
├── docker-compose.yml    # Docker Compose 配置
├── .env.example          # 环境变量示例
└── README.md             # 本文件

config/prometheus/
├── prometheus.yml        # Prometheus 主配置
└── rules/                # 告警规则目录

config/grafana/
└── provisioning/         # 自动数据源配置

config/loki/
├── loki-config.yml       # Loki 配置
└── promtail-config.yml   # Promtail 配置

config/alertmanager/
└── alertmanager.yml      # Alertmanager 配置
```

## 🔒 安全特性

- 全部服务通过 HTTPS 访问
- 安全响应头默认启用
- 容器运行禁止新权限提升（除 cAdvisor 需要特权）
- 支持 Watchtower 自动更新
- Grafana 默认禁用分析报告

## 📊 监控范围

本栈默认监控：
- ✅ 宿主机 CPU、内存、磁盘、网络
- ✅ 所有 Docker 容器资源使用
- ✅ 所有 Docker 容器日志
- ✅ 自定义服务可用性监控（通过 Uptime Kuma）

## 📚 依赖

- Docker 20.10+
- Docker Compose v2+
- Base 栈已部署
