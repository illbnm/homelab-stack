# Notifications Stack — 统一通知中心

该模块基于 **ntfy** 和 **Apprise** 实现 Homelab 的统一通知推送。

## 服务组件

- **ntfy**: 高性能、自托管的推送通知服务器。支持 Android/iOS App、桌面通知、邮件、Webhook。
- **Apprise**: 统一的通知转发网关，支持上百种通知渠道（Telegram, Discord, Slack, Pushover, etc.）。

## 部署与配置

### 1. 配置文件
ntfy 的核心配置位于 `config/ntfy/server.yml`。

### 2. 用户管理 (首次部署后执行)
由于开启了 `auth-default-access: deny-all`，需要手动创建管理员账号：
```bash
docker exec -it ntfy ntfy user add --role=admin <username>
```

## 服务集成说明

### Alertmanager (监控告警)
修改 `config/alertmanager/alertmanager.yml`:
```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

### Watchtower (容器自动更新)
在 `stacks/monitoring/docker-compose.yml` 中添加环境变量:
```yaml
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower
```

### Gitea
1. 进入仓库设置 -> Webhooks。
2. 添加 Gitea Webhook。
3. 目标 URL: `https://ntfy.${DOMAIN}/gitea-repo`。
4. HTTP 方法: `POST`。

### Home Assistant
在 `configuration.yaml` 中配置:
```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/home-assistant
    method: POST
    data:
      title: "{{ title }}"
      message: "{{ message }}"
```

### Uptime Kuma
1. 设置 -> 通知 -> 新建通知。
2. 类型: **ntfy**。
3. ntfy Server URL: `https://ntfy.${DOMAIN}`。
4. Topic: `uptime-kuma`。

## 统一通知脚本
使用提供的脚本进行命令行推送：
```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```
示例：
```bash
./scripts/notify.sh homelab-test "测试告警" "这是来自系统的测试消息" 5
```
