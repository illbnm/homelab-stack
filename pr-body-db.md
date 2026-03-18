## 任务

Closes #11 — `[BOUNTY $130] Database Layer — PostgreSQL + Redis + MariaDB 共享实例`

## 交付内容

### 1. stacks/databases/docker-compose.yml
- PostgreSQL 16.4-alpine 多租户配置
- Redis 7.4.0-alpine 带密码认证 + AOF持久化
- MariaDB 11.5.2 MySQL兼容
- pgAdmin 8.11 管理界面（Traefik暴露）
- Redis Commander 管理界面（Traefik暴露）
- 所有数据库容器含严格健康检查
- 网络隔离：数据库仅 internal 网络

### 2. scripts/init-databases.sh
- 幂等初始化：重复执行不报错
- 为 nextcloud/gitea/outline/authentik/grafana 创建独立 database + user
- 自动由 docker-entrypoint-initdb.d 调用

### 3. scripts/backup-databases.sh
- pg_dumpall 备份所有 PostgreSQL 数据库
- redis-cli BGSAVE + dump.rdb 导出
- 压缩为 .tar.gz，保留最近 7 天
- 可选 MinIO 上传
- 备份完成后通过 notify.sh 推送通知

### 4. stacks/databases/README.md
- 各服务连接字符串示例（PostgreSQL/Redis/MariaDB）
- Redis 多数据库分配表（DB 0-4）
- 管理界面访问说明
- 网络隔离说明
- 备份和定时任务配置
- FAQ

## 验收标准对照

- [x] init-databases.sh 运行后所有数据库和用户创建成功
- [x] init-databases.sh 重复运行不报错（幂等）
- [x] pgAdmin 可访问并连接 PostgreSQL
- [x] 其他 Stack 可通过内部 hostname 连接数据库
- [x] 数据库容器不暴露到宿主机端口（仅内部网络）
- [x] backup-databases.sh 生成有效的 .tar.gz 备份
- [x] README 包含各服务连接字符串示例
