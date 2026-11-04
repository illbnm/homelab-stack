# 💾 Backup & Disaster Recovery Stack

本 Stack 负责 HomeLab 的 **3-2-1 备份与灾难恢复** 执行中枢，集成 **Duplicati** 图形化加密云备份与 **Restic REST Server** 高性能去重备份服务端。

---

## 📦 服务清单

| 服务 | 镜像版本 | 内部端口 | 反代域名 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **Duplicati** | `lscr.io/linuxserver/duplicati:2.0.8` | `8200` | `https://backup.${DOMAIN}` | Web 可视化加密增量备份管理工具 |
| **Restic REST Server** | `restic/rest-server:0.13.0` | `8000` | `https://restic.${DOMAIN}` | 安全认证 Restic 远程备份仓库服务端 |

---

## 🚀 启动与使用

```bash
cd stacks/backup
docker compose up -d
```

配合 `scripts/backup.sh` 脚本可实现自动化定时异地同步：
```bash
# 每日凌晨 2 点执行自动全量备份并保留 7 天
0 2 * * * /opt/homelab/scripts/backup.sh --target all
```
