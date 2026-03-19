---
name: 💰 Bounty - Databases Stack
about: 实现共享数据库栈 (PostgreSQL, Redis, MariaDB) + 管理界面
title: '[BOUNTY $100] Databases Stack — 共享数据库'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$100 USDT**

## 任务描述

实现共享数据库层，供 Nextcloud、Outline、Gitea、Authentik 等服务共用，避免每个服务各自运行独立数据库浪费资源。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| PostgreSQL | `postgres:16.4-alpine` | 主数据库 (多租户) |
| Redis | `redis:7.4.0-alpine` | 缓存/队列 |
| MariaDB | `mariadb:11.5.2` | MySQL 兼容 (Nextcloud 可选) |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL 管理界面 |
| Redis Commander | `rediscommander/redis-commander:latest-sha` | Redis 管理界面 |

## 核心要求

### 1. 多租户 PostgreSQL

`scripts/init-databases.sh` 初始化脚本：

```bash
# 为每个服务创建独立 database + user
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea"     "${GITEA_DB_PASSWORD}"
create_db "outline"   "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD}"
```

脚本必须是**幂等的**（重复执行不报错，不重置已有数据）。

### 2. Redis 多数据库分配

在各服务的 compose 中通过 `?db=N` 参数隔离：

```
DB 0 — Authentik
DB 1 — Outline
DB 2 — Gitea
DB 3 — Nextcloud
DB 4 — Grafana sessions
```

### 3. 备份集成

`scripts/backup-databases.sh`：
- `pg_dumpall` 备份所有 PostgreSQL 数据库
- `redis-cli BGSAVE` 触发 Redis 持久化
- 压缩为 `.tar.gz`，保留最近 7 天
- 可选：上传到 MinIO

### 4. 健康检查

所有数据库容器必须有严格的健康检查，其他 Stack 通过 `depends_on: condition: service_healthy` 等待。

### 5. 网络隔离

数据库服务**不加入** `proxy` 网络，仅暴露给 `internal` 网络，不通过 Traefik 对外暴露（管理界面除外）。

### 6. 环境变量

```bash
POSTGRES_ROOT_PASSWORD=
REDIS_PASSWORD=
MARIADB_ROOT_PASSWORD=
PGADMIN_EMAIL=
PGADMIN_PASSWORD=
# 各服务 DB 密码
NEXTCLOUD_DB_PASSWORD=
GITEA_DB_PASSWORD=
OUTLINE_DB_PASSWORD=
AUTHENTIK_DB_PASSWORD=
```

## 验收标准

- [ ] `init-databases.sh` 运行后所有数据库和用户创建成功
- [ ] `init-databases.sh` 重复运行不报错
- [ ] pgAdmin 可访问并连接 PostgreSQL
- [ ] 其他 Stack (Gitea/Nextcloud) 可通过内部 hostname 连接数据库
- [ ] 数据库容器**不**暴露到宿主机端口（仅内部网络）
- [ ] `backup-databases.sh` 生成有效的 `.tar.gz` 备份
- [ ] README 包含各服务连接字符串示例

## 认领方式

评论 "我来认领"。
