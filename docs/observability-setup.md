# 📊 Observability Stack 配置

## 环境变量

```bash
# Grafana 管理员
ADMIN_USER=admin
ADMIN_PASSWORD=your_secure_password

# 告警邮箱
ALERT_EMAIL=your-email@example.com

# SMTP 配置（可选）
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-smtp-password

# ntfy 通知服务
NTFY_URL=https://ntfy.sh
```

## 快速启动

```bash
# 1. 创建网络
docker network create homelab

# 2. 启动所有服务
cd config/observability
docker-compose up -d

# 3. 访问服务
# Grafana:        http://localhost:3000
# Prometheus:    http://localhost:9090
# Alertmanager:  http://localhost:9093
# Uptime Kuma:   http://localhost:3001
# ntfy:           http://localhost:8090
```

## 服务说明

### Prometheus
- **端口**: 9090
- **功能**: 监控数据采集和存储
- **访问**: http://localhost:9090

### Grafana
- **端口**: 3000
- **功能**: 可视化仪表板
- **默认账号**: admin / admin123

### Loki
- **端口**: 3100
- **功能**: 日志聚合系统

### Alertmanager
- **端口**: 9093
- **功能**: 告警管理和通知

### Uptime Kuma
- **端口**: 3001
- **功能**: 服务状态监控
- **访问**: http://localhost:3001

### ntfy
- **端口**: 8090
- **功能**: 轻量级通知服务
- **访问**: http://localhost:8090

### cAdvisor
- **端口**: 8080
- **功能**: 容器监控
- **访问**: http://localhost:8080

## 使用 Uptime Kuma

### 1. 初始化
1. 访问 http://localhost:3001
2. 创建管理员账号
3. 添加监控服务

### 2. 添加监控服务
```bash
# 示例：监控 Grafana
- 名称: Grafana
- URL: http://grafana:3000
- 监控间隔: 60s

# 示例：监控 Prometheus
- 名称: Prometheus
- URL: http://prometheus:9090
- 监控间隔: 60s
```

### 3. 状态页配置
1. 进入 "Status Pages"
2. 创建公开状态页
3. 添加所有服务

## 告警配置

### ntfy 通知
```bash
# 订阅告警主题
curl -d "Alertmanager connected" ntfy.sh/alertmanager
```

### Email 通知
在 `.env` 中配置 SMTP 信息，Alertmanager 会自动发送邮件

## Grafana Dashboard

### 导入预置 Dashboard
1. 访问 Grafana
2. 进入 "Dashboards" → "Import"
3. 导入以下 Dashboard ID:
   - `1860` (Node Exporter Full)
   - `893` (Docker Container)
   - `14055` (Loki Logs)

### 创建自定义 Dashboard
1. "Create" → "New Dashboard"
2. 添加 Prometheus 查询
3. 配置告警阈值

## 故障排查

### 查看日志
```bash
# Prometheus 日志
docker logs prometheus

# Grafana 日志
docker logs grafana

# Loki 日志
docker logs loki
```

### 重启服务
```bash
docker-compose restart prometheus
docker-compose restart grafana
```

## 数据持久化

所有数据存储在 Docker volumes:
- `prometheus_data`
- `grafana_data`
- `loki_data`
- `alertmanager_data`
- `uptime_kuma_data`

## 安全建议

1. ✅ 修改默认密码
2. ✅ 启用 HTTPS（反向代理）
3. ✅ 限制网络访问
4. ✅ 定期备份数据
5. ✅ 监控资源使用

## 下一步

- [ ] 配置反向代理 (Traefik/Nginx)
- [ ] 添加更多监控目标
- [ ] 创建自定义告警规则
- [ ] 配置 SSO (Authentik)
- [ ] 定期备份 Dashboard

---

**部署完成！** 🎉
