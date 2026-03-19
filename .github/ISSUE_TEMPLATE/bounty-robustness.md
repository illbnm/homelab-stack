---
name: 💰 Bounty - Robustness & CN Network
about: 实现环境鲁棒性与国内网络适配
title: '[BOUNTY $250] Robustness — 环境鲁棒性与国内网络适配'
labels: bounty, hard
assignees: ''
---

## 赏金金额

**$250 USDT**

## 任务描述

让 HomeLab Stack 在任何网络环境下都能可靠部署，特别是针对中国大陆网络环境的完整适配。这是整个项目技术含量最高的 task 之一。

## 核心要求

### 1. Docker 镜像加速

`scripts/setup-cn-mirrors.sh`：

- 交互式询问是否在中国大陆
- 自动写入 `/etc/docker/daemon.json` 镜像加速配置
- 支持多个镜像源（主/备用）
- 验证配置写入后 `docker pull hello-world` 成功

```bash
# 支持的镜像源
mirror.gcr.io
docker.m.daocloud.io
hub-mirror.c.163.com
mirror.baidubce.com
```

### 2. 镜像替换脚本

`scripts/localize-images.sh`：

```bash
# 将所有 compose 文件中的 gcr.io/ghcr.io 替换为国内镜像
./localize-images.sh --cn        # 替换为国内镜像
./localize-images.sh --restore   # 恢复原始镜像
./localize-images.sh --dry-run   # 预览变更不实际修改
./localize-images.sh --check     # 检测当前是否需要替换
```

需要维护完整的镜像映射表 `config/cn-mirrors.yml`：

```yaml
mirrors:
  gcr.io/cadvisor/cadvisor: m.daocloud.io/gcr.io/cadvisor/cadvisor
  ghcr.io/goauthentik/server: m.daocloud.io/ghcr.io/goauthentik/server
  ghcr.io/home-assistant/home-assistant: m.daocloud.io/ghcr.io/home-assistant/home-assistant
  # ... 覆盖所有 gcr.io/ghcr.io 镜像
```

### 3. apt/pip 加速

各服务 entrypoint 脚本中若有包管理器操作，自动切换为国内源：

```bash
# Ubuntu/Debian → 清华源
sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list

# Alpine → 中科大源
sed -i 's|dl-cdn.alpinelinux.org|mirrors.ustc.edu.cn|g' /etc/apk/repositories
```

### 4. 网络连通性检测

`scripts/check-connectivity.sh`：

```
检测项目:
  ✓ Docker Hub 可达性
  ✓ GitHub 可达性
  ✓ gcr.io 可达性
  ✓ ghcr.io 可达性
  ✓ DNS 解析正常
  ✓ 443/80 出站端口开放

输出:
  [OK]   Docker Hub (hub.docker.com) — 延迟 120ms
  [SLOW] GitHub (github.com) — 延迟 1200ms ⚠️ 建议开启镜像加速
  [FAIL] gcr.io — 连接超时 ✗ 需要使用国内镜像

建议: 检测到 2 个不可达源，建议运行 ./scripts/setup-cn-mirrors.sh
```

### 5. install.sh 鲁棒性

`install.sh` 必须处理：

- Docker 未安装 → 自动安装（支持 Ubuntu/Debian/CentOS/Arch）
- Docker Compose v1 → 提示升级到 v2
- 端口冲突检测（53/80/443/3000 等）
- 磁盘空间不足警告（< 20GB 警告，< 5GB 阻止）
- 内存不足警告（< 2GB 警告）
- 非 root 用户 → 自动添加到 docker 组
- 防火墙规则检查（ufw/firewalld）
- 断网重试（`curl` 失败最多重试 3 次，指数退避）

```bash
# 所有网络请求使用此包装函数
curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 $max_attempts); do
    curl --connect-timeout 10 --max-time 60 "$@" && return 0
    echo "Attempt $i failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
  return 1
}
```

### 6. docker compose 健康等待

`scripts/wait-healthy.sh --stack <name> --timeout 300`：

- 等待所有容器健康检查通过
- 每 5 秒轮询一次
- 超时后打印未健康容器的 logs（最后 50 行）
- 退出码：0=全部健康，1=超时，2=容器退出

### 7. 一键诊断

`scripts/diagnose.sh`：

收集并输出（或写入 `diagnose-report.txt`）：
- Docker 版本
- 系统信息（OS/内核/内存/磁盘）
- 所有容器状态
- 近期错误日志
- 网络连通性测试结果
- 配置文件校验结果

用于用户提 issue 时提交诊断报告。

## 验收标准

- [ ] `check-connectivity.sh` 准确检测各镜像源可达性
- [ ] `setup-cn-mirrors.sh` 配置后 `docker pull` 速度提升可验证
- [ ] `localize-images.sh --cn` 替换后所有 compose 文件中无 gcr.io/ghcr.io
- [ ] `localize-images.sh --restore` 能完整恢复
- [ ] `install.sh` 在全新 Ubuntu 22.04 上执行无报错
- [ ] `install.sh` 在已安装 Docker 的环境下重复执行无报错
- [ ] `wait-healthy.sh` 超时后输出有用的错误信息
- [ ] `diagnose.sh` 生成完整诊断报告
- [ ] 所有 shell 脚本通过 `shellcheck` 无 error

## 认领方式

评论 "我来认领"。
