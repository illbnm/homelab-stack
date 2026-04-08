# 环境鲁棒性与国内网络适配

本项目的安装脚本和部署流程经过特别优化，能够在各种网络环境下（特别是中国大陆）可靠运行。

## 🚀 核心功能

### 1. 网络连通性检测 (`scripts/check-connectivity.sh`)

自动检测各 Docker 镜像源和 GitHub 的连通性：

```bash
./scripts/check-connectivity.sh
```

**检测项目：**
- Docker Hub、gcr.io、ghcr.io、quay.io 连通性
- GitHub 访问速度
- 国内镜像源可用性
- DNS 解析
- 出站端口开放状态
- 系统时间同步

**输出示例：**
```
[OK]   Docker Hub (hub.docker.com) — 延迟 120ms
[SLOW] GitHub (github.com) — 延迟 1200ms ⚠️
[FAIL] gcr.io — 连接超时 ✗
```

### 2. Docker 镜像加速配置 (`scripts/setup-cn-mirrors.sh`）

交互式配置 Docker daemon 使用国内镜像源：

```bash
sudo ./scripts/setup-cn-mirrors.sh
```

**支持的镜像源：**
- mirror.gcr.io (Google 官方镜像)
- docker.m.daocloud.io (DaoCloud)
- hub-mirror.c.163.com (网易)
- mirror.baidubce.com (百度云)

**功能：**
- 自动备份现有配置
- 配置多个镜像源（主/备用）
- 重启 Docker 服务
- 验证配置生效
- 测试镜像拉取

### 3. 镜像源替换 (`scripts/localize-images.sh`)

批量替换 compose 文件中的 gcr.io/ghcr.io 为国内镜像：

```bash
# 检查是否需要替换
./scripts/localize-images.sh --check

# 预览替换结果（不修改文件）
./scripts/localize-images.sh --dry-run

# 执行替换
./scripts/localize-images.sh --cn

# 恢复原始配置
./scripts/localize-images.sh --restore
```

**镜像映射配置：** `config/cn-mirrors.yml`

包含完整的镜像映射表，覆盖：
- Google Container Registry (gcr.io)
- GitHub Container Registry (ghcr.io)
- Kubernetes (k8s.gcr.io)
- Quay.io

### 4. 容器健康等待 (`scripts/wait-healthy.sh`)

等待 stack 中所有容器健康检查通过：

```bash
./scripts/wait-healthy.sh --stack sso --timeout 300
```

**功能：**
- 每 5 秒轮询容器状态
- 检测容器退出/死亡
- 超时后显示未健康容器的日志
- 退出码：0=全部健康，1=超时，2=容器退出

### 5. 系统诊断 (`scripts/diagnose.sh`)

收集完整的系统诊断信息：

```bash
./scripts/diagnose.sh
```

**收集内容：**
- 系统信息（OS/内核/内存/磁盘）
- Docker 版本和配置
- 所有容器状态
- 近期错误日志
- 网络连通性测试
- 配置文件验证

**输出：** `diagnose-report.txt`

用于提交 Issue 时提供完整的系统信息。

### 6. 增强的安装脚本 (`install.sh`)

**健壮性改进：**

1. **资源检查**
   - 内存检查（<2GB 警告）
   - 磁盘空间检查（<5GB 阻止，<20GB 警告）

2. **端口冲突检测**
   - 检查 53/80/443/3000/8080/9000 端口占用

3. **防火墙检查**
   - UFW/Firewalld 状态检测
   - 提示开放必要端口

4. **Docker 自动安装**
   - 支持 Ubuntu/Debian/CentOS/Arch
   - 自动添加用户到 docker 组

5. **Docker Compose 版本检查**
   - 检测 v1 vs v2
   - 提示升级建议

6. **网络重试机制**
   - 所有 curl 请求最多重试 3 次
   - 指数退避（5s → 10s → 20s）

7. **非 root 用户支持**
   - 检测并提示添加到 docker 组
   - 自动使用 sudo 执行必要命令

8. **完整的日志记录**
   - 所有操作记录到 `~/.homelab/install.log`
   - 失败时显示日志位置

## 📋 使用示例

### 场景 1: 全新安装（中国大陆）

```bash
# 1. 检查网络
./scripts/check-connectivity.sh

# 2. 配置镜像加速（如需要）
sudo ./scripts/setup-cn-mirrors.sh

# 3. 运行安装脚本（会自动处理依赖）
./install.sh

# 4. 检查服务健康
./scripts/wait-healthy.sh --stack sso --timeout 300
```

### 场景 2: 镜像源问题排查

```bash
# 1. 检测连通性
./scripts/check-connectivity.sh

# 2. 检查镜像配置
./scripts/localize-images.sh --check

# 3. 如需要，执行替换
./scripts/localize-images.sh --cn

# 4. 恢复（如需要）
./scripts/localize-images.sh --restore
```

### 场景 3: 问题诊断

```bash
# 生成诊断报告
./scripts/diagnose.sh

# 查看报告
cat diagnose-report.txt
```

## 🔧 配置文件

### config/cn-mirrors.yml

镜像映射配置文件，包含：

- **mirrors**: 具体镜像的映射关系
- **fallback_rules**: 通用回退规则（匹配模式）
- **alternatives**: 备用镜像源列表

## ✅ 测试验证

运行测试套件：

```bash
./scripts/test-robustness.sh
```

验证内容：
- 所有脚本存在且可执行
- 语法检查通过
- 参数验证正确
- 诊断报告生成成功
- install.sh 包含所有健壮性特性

## 🐛 故障排除

### 问题：Docker pull 失败

```bash
# 1. 检查网络
./scripts/check-connectivity.sh

# 2. 配置镜像加速
sudo ./scripts/setup-cn-mirrors.sh

# 3. 替换 compose 文件中的镜像
./scripts/localize-images.sh --cn
```

### 问题：安装脚本失败

```bash
# 查看详细日志
cat ~/.homelab/install.log

# 生成诊断报告
./scripts/diagnose.sh
```

### 问题：容器不健康

```bash
# 查看容器状态
docker ps -a

# 查看特定容器日志
docker logs <container-name> --tail 100

# 等待健康检查
./scripts/wait-healthy.sh --stack <name> --timeout 300
```

## 📚 相关文档

- [安装指南](../docs/getting-started.md)
- [故障排除](../docs/troubleshooting.md)
- [网络配置](../docs/network-config.md)

## 🤝 贡献

如果您发现其他需要添加的国内镜像源或改进建议，欢迎提交 PR！

---

**注意：** 所有脚本都通过 `shellcheck` 验证，符合 bash 最佳实践。
