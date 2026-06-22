# Disaster Recovery (DR) 灾难恢复演练文档

本文档详细描述了发生灾难（例如硬件损坏、系统崩溃等）时的恢复流程。基于 3-2-1 备份策略（3 份数据，2 种介质，1 份异地），确保数据万无一失。

## 恢复策略说明

- **本地备份仓库**：位于 `Restic REST Server` 中。
- **云端备份仓库**：如 Amazon S3, Backblaze B2, 或是 `Duplicati` 管理的远端存储。
- **RTO (预计恢复时间)**：< 2 小时（取决于网络带宽及数据量）。
- **RPO (预计数据丢失)**：最多 24 小时（取决于定时备份频率）。

## 完整恢复流程（全新主机从零恢复）

1. **基础环境安装**
   在新的 Linux 系统上安装 Docker 和 Docker Compose。
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
   安装并克隆 `homelab-stack` 仓库。
   ```bash
   git clone https://github.com/illbnm/homelab-stack.git /opt/homelab-stack
   cd /opt/homelab-stack
   ```

2. **恢复配置文件 (.env)**
   如果你的代码库中包含最新的 `config/` 和 `stacks/` 的备份，可通过 restic 直接恢复配置文件：
   ```bash
   export RESTIC_PASSWORD="<你的备份密码>"
   export RESTIC_REPOSITORY="<你的远端仓库地址如s3>"
   # 临时恢复配置
   docker run --rm -v $(pwd):/restore restic/restic:0.16.3 -r $RESTIC_REPOSITORY restore latest --target /restore --tag configs
   ```
   确认 `.env` 变量无误，特别是密码和云存储密钥。

3. **创建 Proxy 网络**
   启动集群之前，务必创建外部网络：
   ```bash
   docker network create proxy
   ```

4. **恢复服务数据（顺序执行）**

   使用重写的 `backup.sh` 脚本从远端或本地恢复每个 Stack。
   > **注意**：恢复时需要保证目标 Stack 的容器为停止状态（因为容器正在运行可能会写入冲突）。

   **推荐的恢复顺序**：
   1. **Base (Traefik, Portainer)**: 
      ```bash
      ./scripts/backup.sh --restore latest --target base
      docker compose -f stacks/base/docker-compose.yml up -d
      ```
   2. **Databases (PostgreSQL, MariaDB, Redis)**:
      ```bash
      ./scripts/backup.sh --restore latest --target databases
      docker compose -f stacks/databases/docker-compose.yml up -d
      ```
   3. **SSO (Authentik)**:
      ```bash
      ./scripts/backup.sh --restore latest --target sso
      docker compose -f stacks/sso/docker-compose.yml up -d
      ```
   4. **其他业务服务 (Media, Nextcloud, Vaultwarden 等)**:
      ```bash
      ./scripts/backup.sh --restore latest --target <stack_name>
      docker compose -f stacks/<stack_name>/docker-compose.yml up -d
      ```

## 定时备份设置

日常备份依赖 cron 进行调度。在宿主机执行 `crontab -e` 并添加：
```bash
0 2 * * * /opt/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

## 验证恢复完整性的检查清单

- [ ] `Traefik` 仪表盘可访问，并显示所有路由配置正常。
- [ ] 尝试登录 `Authentik` (SSO) 测试认证系统是否可用。
- [ ] 检查 `PostgreSQL` / `MariaDB` 的日志是否包含异常的数据库崩溃恢复信息。
- [ ] 访问并播放媒体库（`Media` stack），确认大文件是否完整。
- [ ] 测试核心服务（例如 `Vaultwarden`, `Nextcloud`）的读写和数据展示。
