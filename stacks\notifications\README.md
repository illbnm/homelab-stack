# 📬 Notifications Stack — 统一通知中心

> ntfy + Gotify 双后端推送，统一 `notify.sh` 接口供所有服务调用。

---

## 目录

- [服务概览](#服务概览)
- [快速启动](#快速启动)
- [初始配置](#初始配置)
  - [ntfy 账号管理](#ntfy-账号管理)
  - [Gotify 应用 Token](#gotify-应用-token)
- [测试推送](#测试推送)
- [notify.sh 脚本使用](#notifysh-脚本使用)
- [服务集成](#服务集成)
  - [Alertmanager](#alertmanager)
  - [Watchtower](#watchtower)
  - [Gitea Webhook](#gitea-webhook)
  - [Home Assistant](#home-assistant)
  - [Uptime Kuma](#uptime-kuma)
- [手机 App 配置](#手机-app-配置)
- [主题规划建议](#主题规划建议)
- [故障排查](#故障排查)

---

## 服务概览

| 服务   | 镜像                          | 端口  | 用途             |
|--------|-------------------------------|-------|------------------|
| ntfy   | `binwiederhier/ntfy:v2.11.0`  | 2586  | 主推送服务器     |
| Gotify | `gotify/server:2.5.0`         | 8070  | 备用推送服务     |

**访问地址**（Traefik 反代后）:
- ntfy Web UI: `https://ntfy.yourdomain.com`
- Gotify Web UI: `https://gotify.yourdomain.com`

---

## 快速启动

### 1. 配置环境变量

在项目根目录 `.env` 文件中添加以下配置：

