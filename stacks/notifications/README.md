# Notifications Stack — ntfy + Apprise 统一通知中心

One-command push notifications for every other stack (Watchtower, Alertmanager,
Gitea, Uptime Kuma…). Fix for issue #13 ($80).

## 启动

```bash
cp config/.env.example config/.env   #填 DOMAIN=你的域名
docker compose -f stacks/notifications/docker-compose.yml up -d
./scripts/notify.sh alerts "Homelab" "通知中心已上线" high
```

首次启动后建 ntfy 用户（见 `config/ntfy/server.yml` 注释）。

## 配置说明

| 服务 | 配置方式 |
|---|---|
| Alertmanager | `receivers: ntfy` 已接好（`config/alertmanager/alertmanager.yml`），改 `http://ntfy:80/alerts` |
| Watchtower | `WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/backups` |
| Gitea | repo Settings → Webhooks → `http://ntfy:80/gitea` |
| Home Assistant | `notify: platform: ntfy, resource: http://ntfy:80/ha` |
| Uptime Kuma | Notification Type → ntfy，填 `http://ntfy:80/uptime` |

所有脚本统一调 `./scripts/notify.sh <topic> <title> <message> [priority]`，
不直调 ntfy/Apprise API。Apprise（`apprise.${DOMAIN}`）做备用通道。

## 常见问题

- **收不到推送？** 先 `curl http://localhost:2586/v1/health`，再看 topic 权限
  （`auth-default-access: deny-all`，记得给 topic 配 read-write）。
- **HTTPS？** Traefik 自动签 `ntfy.${DOMAIN}` / `apprise.${DOMAIN}`。
- **换 Gotify？** Apprise 原生兼容 gotify URL（`gotify://host/token`），
  无需改本栈——换 `APPRISE_URL` 即可。
