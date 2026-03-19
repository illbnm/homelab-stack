# Robustness Stack — 系统鲁棒性与网络适配 🛠️

提供环境自检、网络加速、一键诊断和故障排除工具，确保 homelab 稳定运行。

---

## 🎯 核心价值

### 为什么需要 Robustness?

- **自动安装** — 一键安装 Docker、Docker Compose、Clone 仓库
- **网络适配** — 中国大陆镜像加速，解决 GCR/GHCR 拉取慢问题
- **连通性检测** — 自动检测外部服务可达性
- **故障诊断** — 一键收集系统信息，快速定位问题
- **降低门槛** — 新手也能 10 分钟完成部署

---

## 📦 组件

| 脚本 | 用途 |
|------|------|
| `install.sh` | 一键安装 Docker、Clone 仓库、配置环境 |
| `check-connectivity.sh` | 检测与 Docker Hub、GHCR、GCR 等的连通性 |
| `diagnose.sh` | 收集系统信息 (Docker、网络、磁盘、内存、容器) |
| `localize-images.sh` | 应用中国镜像加速配置 |
| `entrypoint-setup.sh` | 容器化 setup 环境入口 |

---

## 🚀 快速开始

### 方法 1: 本地运行 (推荐)

```bash
# 1. 克隆仓库 (如果还没)
git clone https://github.com/aerospaziale/homelab-stack.git
cd homelab-stack

# 2. 一键安装
chmod +x scripts/install.sh
./scripts/install.sh

# 3. 按提示编辑 .env，设置密码

# 4. 启动所需 Stack
docker compose -f stacks/base/docker-compose.yml up -d
docker compose -f stacks/network/docker-compose.yml up -d
```

### 方法 2: 容器化运行

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v $(pwd):/workspace \
  -v $(pwd)/stacks/robustness/config:/config:ro \
  homelab-setup  # 需先构建
```

---

## 🔧 工具详解

### 1. install.sh — 一键安装

**功能**:
- 检测 OS (Linux/macOS)
- 自动安装 Docker
- 安装 Docker Compose 插件
- 克隆 homelab-stack 仓库
- 创建 `.env` 模板
- 启动 Base Stack (Traefik, Portainer)
- 可选应用镜像加速

**使用**:
```bash
./scripts/install.sh
```

**交互流程**:
```
=== homelab-stack 一键安装 ===
Docker 未安装，开始安装...
✅ Docker 安装完成
✅ Docker Compose 已安装
克隆 homelab-stack 仓库...
✅ 仓库已存在
创建 .env 配置文件...
✅ .env 已创建
启动 Base Stack...
等待 Traefik 就绪...
是否应用中国大陆镜像加速配置? [y/N]: y
✅ 镜像加速已配置
=== 安装完成 ===
```

### 2. check-connectivity.sh — 连通性检测

**功能**: 测试与 Docker Hub、GHCR、GCR 等外部服务的连接

**使用**:
```bash
./scripts/check-connectivity.sh
```

**输出示例**:
```
=== 网络连通性检测 ===
测试目标: https://docker.io https://hub.docker.com https://ghcr.io
Testing https://docker.io... ✓
Testing https://hub.docker.com... ✗
Testing https://ghcr.io... ✓

⚠️  1 个目标不可达
建议:
1. 检查 DNS 配置
2. 检查防火墙规则
3. 使用代理或镜像加速
```

**自动修复**: 如果检测到 GHCR/GCR 不可达，提示运行 `localize-images.sh`

### 3. diagnose.sh — 系统诊断

**功能**: 收集系统健康信息

**输出**:
- Docker 版本和信息
- Docker Compose 版本
- 磁盘空间
- 内存使用
- 网络配置 (路由、DNS)
- 运行中的容器
- Docker 镜像列表
- 最近错误日志

**使用**:
```bash
./scripts/diagnose.sh
```

**报告保存**: `/tmp/diagnose-YYYYMMDD-HHMMSS.txt`

**示例问题排查**:
```
=== docker logs (最近 container) ===
=== traefik ===
level=error msg="Failed to obtain ACME certificate"
# → 域名解析问题，检查 DNS A 记录
```

### 4. localize-images.sh — 镜像加速

**功能**: 将所有 Stack 的镜像替换为国内镜像源

**配置**: `stacks/robustness/config/cn-mirrors.yml`

**使用**:
```bash
./scripts/localize-images.sh
```

**映射表** (示例):
```yaml
mirrors:
  gcr:
    mirrors:
      - https://gcr.nju.edu.cn
  ghcr:
    mirrors:
      - https://ghcr.nju.edu.cn
  quay:
    mirrors:
      - https://quay-mirror.tuna.tsinghua.edu.cn
```

**自动替换**: `sed -i` 批量替换 `docker-compose.yml` 中的镜像地址

**注意**: 先备份，再替换。测试前验证镜像是否可用。

### 5. entrypoint-setup.sh — 容器入口

**功能**: 在容器内执行 setup 流程

**使用场景**: 作为 Robustness Stack docker-compose.yml 的 entrypoint

**检查项**:
- Docker 可达
- 网络连通性
- 配置文件存在
- 运行诊断

---

## 📁 目录结构

```
homelab-stack/
├── scripts/
│   ├── install.sh          # 一键安装
│   ├── check-connectivity.sh  # 连通性检测
│   ├── diagnose.sh         # 系统诊断
│   ├── localize-images.sh  # 镜像加速
│   └── entrypoint-setup.sh # 容器入口
└── stacks/
    └── robustness/
        ├── docker-compose.yml
        ├── config/
        │   └── cn-mirrors.yml  # 镜像映射配置
        └── README.md
```

---

## 🐛 常见问题

### 1. Docker 安装失败

```bash
# 查看详细日志
sudo journalctl -u docker.service -n 50

# 常见原因: 内核版本过低
# 解决: 更新内核或使用 Docker Desktop (macOS)
```

### 2. 镜像拉取慢或超时

```bash
# 1. 检测连通性
./scripts/check-connectivity.sh

# 2. 应用镜像加速
./scripts/localize-images.sh

# 3. 手动测试镜像
docker pull gcr.io/kubernetes-entrypoint/kubernetes-entrypoint:debian-v0.3.0
```

### 3. 端口冲突

```bash
# 查找占用 80/443 的进程
sudo ss -tulpn | grep -E ':80|:443'

# 停止冲突服务
sudo systemctl stop nginx apache2
```

### 4. 权限问题

```bash
# 添加用户到 docker 组
sudo usermod -aG docker $USER
newgrp docker  # 或重新登录

# 验证
docker ps
```

### 5. 磁盘空间不足

```bash
# 清理未使用资源
docker system prune -a --volumes

# 检查 /var/lib/docker 大小
du -sh /var/lib/docker
```

---

## 🔄 与其他 Stack 的关系

```
Robustness Stack 优先于其他 Stack 运行:
1. install.sh → 安装 Docker + 基础配置
2. check-connectivity.sh → 检测网络
3. localize-images.sh (可选) → 镜像加速
4. diagnose.sh (随时) → 故障排查
5. 其他 Stack 启动
```

---

## ✅ 验收标准

- [x] `install.sh` 支持 Linux/macOS，自动安装 Docker
- [x] `install.sh` 创建 `.env` 模板并启动 Base Stack
- [x] `check-connectivity.sh` 检测主要镜像源 (Docker Hub, GHCR, GCR)
- [x] `check-connectivity.sh` 输出明确通过/失败
- [x] `diagnose.sh` 收集完整系统信息
- [x] `diagnose.sh` 生成报告文件并提供建议
- [x] `localize-images.sh` 读取 `cn-mirrors.yml` 配置
- [x] `localize-images.sh` 备份原文件再替换
- [x] README 说明所有工具的使用方法和适用场景
- [x] 所有脚本具备错误处理和友好提示

---

## 📸 验收材料

1. **install.sh 演示**:
   ```bash
   ./scripts/install.sh
   # 输出: ✅ Docker 安装完成, ✅ Docker Compose 已安装, ✅ 仓库已克隆
   ```

2. **check-connectivity.sh**:
   ```bash
   ./scripts/check-connectivity.sh
   # 测试至少 5 个目标 URL，报告可达性
   ```

3. **diagnose.sh**:
   ```bash
   ./scripts/diagnose.sh
   # 生成报告文件，包含 docker version, df -h, free, docker ps 等
   ```

4. **localize-images.sh**:
   ```bash
   ./scripts/localize-images.sh
   # 备份 stacks/ 到 stacks-backup-YYYYMMDD-HHMMSS
   # 批量替换镜像地址
   git diff stacks/base/docker-compose.yml  # 查看替换效果
   ```

5. **镜像加速验证**:
   ```bash
   # 替换前
   docker pull gcr.io/kubernetes-entrypoint/kubernetes-entrypoint:debian-v0.3.0
   # (慢或失败)
   # 替换后
   docker pull gcr.nju.edu.cn/kubernetes-entrypoint/kubernetes-entrypoint:debian-v0.3.0
   # (快)
   ```

6. **全流程 end-to-end**:
   ```bash
   # 全新机器
   ./scripts/install.sh
   # 选择应用镜像加速
   ./scripts/localize-images.sh
   # 启动一个 Stack
   docker compose -f stacks/base/docker-compose.yml up -d
   # 验证 Traefik 可访问
   curl -k https://traefik.${DOMAIN}
   ```

---

## 🎯 适用场景

1. **新服务器部署** — 从零开始一键安装
2. **中国用户** — 镜像加速，解决网络问题
3. **故障排查** — 收集系统信息求助
4. **CI/CD 前置检查** — 验证环境是否就绪

---

## 🔐 安全说明

- `install.sh` 会下载 Docker 官方脚本，确保网络环境可信
- `diagnose.sh` 收集系统信息，报告文件包含敏感路径，妥善保管
- `localize-images.sh` 使用国内镜像源，确保镜像来源可信 (官方镜像同步)

---

## 📚 参考

- Docker 官方安装脚本: https://get.docker.com
- 清华镜像站: https://mirrors.tuna.tsinghua.edu.cn
- 南京大学镜像: https://mirror.nju.edu.cn
- 中科大镜像: https://mirrors.ustc.edu.cn

---

**让部署更简单，让问题无处藏身！** 🛠️🔍

---

**Fixes #147 (Robustness Bounty $250)**  
Closes #147