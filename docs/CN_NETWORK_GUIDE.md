# 国内网络适配指南

本指南介绍如何在中国大陆网络环境下部署 HomeLab Stack，包括 Docker 镜像加速、apt/pip 源配置、网络连通性检测等。

## 📋 目录

- [快速开始](#快速开始)
- [Docker 镜像加速](#docker-镜像加速)
- [镜像替换工具](#镜像替换工具)
- [网络连通性检测](#网络连通性检测)
- [健康检查等待](#健康检查等待)
- [故障排查](#故障排查)

---

## 🚀 快速开始

如果你在中国大陆，运行以下命令一键配置：

```bash
# 1. 自动检测并配置 Docker 镜像加速
sudo ./scripts/setup-cn-mirrors.sh --auto

# 2. 替换 compose 文件中的镜像为国内源
./scripts/localize-images.sh --cn

# 3. 检测网络连通性
./scripts/check-connectivity.sh

# 4. 启动服务并等待健康
docker compose up -d
./scripts/wait-healthy.sh --stack base --timeout 300
```

---

## 🐳 Docker 镜像加速

### 自动配置

```bash
sudo ./scripts/setup-cn-mirrors.sh --auto
```

脚本会自动：
- 检测是否在国内网络环境
- 备份现有 Docker 配置
- 配置多个镜像加速源（主 + 备用）
- 重启 Docker 服务
- 验证配置是否生效

### 手动配置

```bash
# 强制配置（跳过检测）
sudo ./scripts/setup-cn-mirrors.sh --force

# 恢复原始配置
sudo ./scripts/setup-cn-mirrors.sh --restore

# 仅检查网络环境
./scripts/setup-cn-mirrors.sh --check

# 列出可用镜像源
./scripts/setup-cn-mirrors.sh --list
```

### 支持的镜像源

| 镜像源 | 地址 |
|--------|------|
| DaoCloud (主) | `gcr.m.daocloud.io` |
| DaoCloud Docker Hub | `docker.m.daocloud.io` |
| 网易云 | `hub-mirror.c.163.com` |
| 百度云 | `mirror.baidubce.com` |
| 阿里云 | `registry.cn-hangzhou.aliyuncs.com` |

### 手动配置 daemon.json

```json
{
  "registry-mirrors": [
    "https://gcr.m.daocloud.io",
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com"
  ]
}
```

---

## 🔄 镜像替换工具

### 替换为国内镜像

```bash
# 替换所有 compose 文件
./scripts/localize-images.sh --cn

# 预览变更（不实际修改）
./scripts/localize-images.sh --cn --dry-run

# 仅处理指定文件
./scripts/localize-images.sh --cn --file docker-compose.yml
```

### 恢复原始镜像

```bash
# 恢复所有 compose 文件
./scripts/localize-images.sh --restore

# 预览恢复效果
./scripts/localize-images.sh --restore --dry-run
```

### 检查状态

```bash
# 检测哪些文件需要替换
./scripts/localize-images.sh --check
```

### 配置文件

镜像映射表位于 `config/cn-mirrors.yml`，包含：
- GCR.io 镜像映射
- GHCR.io 镜像映射
- Quay.io 镜像映射
- Docker.io 镜像映射
- apt/pip/npm 包管理器镜像源

---

## 🌐 网络连通性检测

### 运行检测

```bash
./scripts/check-connectivity.sh
```

检测项目：
- ✅ Docker Hub 可达性
- ✅ GitHub 可达性
- ✅ GCR.io 可达性
- ✅ GHCR.io 可达性
- ✅ Quay.io 可达性
- ✅ DNS 解析正常
- ✅ 443/80 出站端口开放
- ✅ Docker 配置检查

### 输出示例

```
[OK] Docker Hub (hub.docker.com) — 延迟 120ms
[SLOW] GitHub (github.com) — 延迟 1200ms ⚠️ 建议开启镜像加速
[FAIL] gcr.io — 连接超时 ✗ 需要使用国内镜像
```

### JSON 输出

```bash
./scripts/check-connectivity.sh --json
```

---

## ⏳ 健康检查等待

### 等待 Stack 健康

```bash
# 等待基础服务健康（超时 300 秒）
./scripts/wait-healthy.sh --stack base --timeout 300

# 等待媒体服务健康（超时 600 秒）
./scripts/wait-healthy.sh --stack media --timeout 600
```

### 列出所有 Stack

```bash
./scripts/wait-healthy.sh --list
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--stack` | Stack 名称 | 必需 |
| `--timeout` | 超时时间（秒） | 300 |
| `--interval` | 检查间隔（秒） | 5 |

---

## 🔧 故障排查

### Docker pull 失败

**问题**: `dial tcp: lookup gcr.io: no such host`

**解决**:
```bash
# 配置国内镜像
sudo ./scripts/setup-cn-mirrors.sh --auto

# 或手动编辑 /etc/docker/daemon.json
sudo systemctl restart docker
```

### GitHub 访问慢

**问题**: Clone 或 pull 速度极慢

**解决**:
```bash
# 使用镜像站
git clone https://ghproxy.com/https://github.com/illbnm/homelab-stack.git

# 或配置 Git 代理
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy https://127.0.0.1:7890
```

### apt 更新慢

**问题**: `apt update` 速度极慢或超时

**解决**:
编辑 `/etc/apt/sources.list`，替换为清华源：

```bash
# Ubuntu 22.04
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
```

### pip 安装慢

**问题**: `pip install` 速度极慢

**解决**:
```bash
# 临时使用清华源
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple <package>

# 永久配置
mkdir -p ~/.pip
cat > ~/.pip/pip.conf <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
```

### npm 安装慢

**问题**: `npm install` 速度极慢

**解决**:
```bash
# 使用淘宝镜像
npm config set registry https://registry.npmmirror.com

# 验证
npm config get registry
```

### 容器健康检查失败

**问题**: 容器一直处于 `starting` 状态

**解决**:
```bash
# 查看容器日志
docker logs <container-name>

# 查看健康检查详情
docker inspect --format='{{json .State.Health}}' <container-name> | jq

# 重启容器
docker compose restart <service-name>
```

---

## 📚 相关文档

- [安装指南](./INSTALL.md)
- [快速开始](./docs/getting-started.md)
- [Stack 管理](./scripts/stack-manager.sh)
- [故障排查](./docs/troubleshooting.md)

---

## 💡 提示

1. **首次部署**: 建议先运行 `check-connectivity.sh` 检测网络环境
2. **镜像加速**: 在国内务必配置 Docker 镜像加速，可提升 10 倍以上速度
3. **定期更新**: 镜像源可能变化，建议定期运行 `setup-cn-mirrors.sh --check`
4. **备份配置**: 脚本会自动备份，也可手动备份 `/etc/docker/daemon.json`

---

## 🆘 获取帮助

如遇到问题：
1. 查看详细日志：`~/.homelab/install.log`
2. 运行网络检测：`./scripts/check-connectivity.sh`
3. 查看容器状态：`docker compose ps`
4. 查看容器日志：`docker compose logs <service>`
