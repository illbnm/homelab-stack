# 💰 HomeLab Stack — 赏金任务总览

> 本项目通过赏金机制驱动开发。每个 task 独立可认领，完成后按验收标准审核发放。

## 总赏金池

| # | Task | 难度 | 赏金 | 状态 |
|---|------|------|------|------|
| 1 | [Base Infrastructure — Traefik + Portainer + Watchtower](https://github.com/illbnm/homelab-stack/issues/1) | 🟡 Medium | $180 | 🟢 Open |
| 2 | [Media Stack — Jellyfin + Sonarr + Radarr + qBittorrent](https://github.com/illbnm/homelab-stack/issues/2) | 🟡 Medium | $160 | 🟢 Open |
| 3 | [Storage Stack — Nextcloud + MinIO + FileBrowser](https://github.com/illbnm/homelab-stack/issues/3) | 🟡 Medium | $150 | 🟢 Open |
| 4 | [Network Stack — AdGuard + WireGuard + Nginx Proxy Manager](https://github.com/illbnm/homelab-stack/issues/4) | 🟡 Medium | $140 | 🟢 Open |
| 5 | [Productivity Stack — Gitea + Vaultwarden + Outline + Stirling PDF + Excalidraw](https://github.com/illbnm/homelab-stack/issues/5) | 🟡 Medium | $160 | 🟢 Open |
| 6 | [AI Stack — Ollama + Open WebUI + Stable Diffusion](https://github.com/illbnm/homelab-stack/issues/6) | 🔴 Hard | $220 | 🟢 Open |
| 7 | [Home Automation — Home Assistant + Node-RED + Zigbee2MQTT](https://github.com/illbnm/homelab-stack/issues/7) | 🟡 Medium | $130 | 🟢 Open |
| 8 | [Robustness — 国内网络适配 + 环境鲁棒性](https://github.com/illbnm/homelab-stack/issues/8) | 🔴 Hard | $250 | 🟢 Open |
| 9 | [SSO — Authentik 统一身份认证](https://github.com/illbnm/homelab-stack/issues/9) | 🔴 Hard | $300 | 🟢 Open |
| 10 | [Observability — Prometheus + Grafana + Loki + Alerting](https://github.com/illbnm/homelab-stack/issues/10) | 🔴 Hard | $280 | 🟢 Open |
| 11 | [Database Layer — PostgreSQL + Redis + MariaDB 共享实例](https://github.com/illbnm/homelab-stack/issues/11) | 🟡 Medium | $130 | 🟢 Open |
| 12 | [Backup & DR — 自动备份 + 灾难恢复](https://github.com/illbnm/homelab-stack/issues/12) | 🟡 Medium | $150 | 🟢 Open |
| 13 | [Notifications — ntfy + Apprise 通知中心](https://github.com/illbnm/homelab-stack/issues/13) | 🟢 Easy | $80 | 🟢 Open |
| 14 | [Testing Framework — 全栈自动化测试](https://github.com/illbnm/homelab-stack/issues/14) | 🔴 Hard | $200 | 🟢 Open |

**总计：$2,340 USDT**

---

## 如何参与

1. 在对应 Issue 下评论 "我来认领"
2. Fork 本仓库，在功能分支开发
3. 完成后提交 Pull Request
4. 通过验收后获得赏金

## 验收标准

每个任务需满足：

1. **功能完整** — 所有服务正常启动、健康检查通过
2. **配置规范** — 环境变量通过 `.env` 管理，无硬编码
3. **网络正确** — Traefik 反代配置完整，HTTPS 生效
4. **SSO 集成** — 支持 Authentik OIDC/Forward Auth（适用服务）
5. **文档清晰** — README 包含启动步骤、配置说明、常见问题
6. **镜像锁定** — 所有镜像 tag 为具体版本号，禁止 `latest`
7. **CN 适配** — gcr.io/ghcr.io 镜像提供国内替代源

## 支付方式

- USDT (TRC20) / PayPal / 支付宝 / 微信
- 验收通过后 3 个工作日内支付
