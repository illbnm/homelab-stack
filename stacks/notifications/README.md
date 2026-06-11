# 📢 Notifications Stack

统一通知中心，为所有 HomeLab 服务提供集中式通知推送能力。

## 服务组成

| 服务 | 镜像 | 用途 |
|------|------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 主推送通知服务器 |
| Gotify | `gotify/server:2.5.0` | 备用推送服务 |
| Apprise | `caronc/apprise:latest` | 统一通知路由网关 |

## 快速开始

