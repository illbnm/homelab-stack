# Robustness Stack - 测试文档

## 概述

本文档提供 HomeLab Stack 鲁棒性功能的完整测试指南。

## 测试环境

- **操作系统**: Ubuntu 22.04 LTS / Debian 12 / Alpine 3.19
- **Docker**: >= 24.0
- **Docker Compose**: v2.x
- **网络**: 支持中国大陆镜像加速

---

## 1. 脚本语法检查

### 测试目标
验证所有脚本语法正确，无解析错误。

### 测试命令

```bash
cd /path/to/homelab-stack

# 检查所有脚本语法
for script in scripts/*.sh; do
  echo "=== Testing $script ==="
  bash -n "$script" && echo "✓ PASS" || echo "✗ FAIL"
done

# 使用 shellcheck 进行静态分析
for script in scripts/setup-*.sh scripts/check-*.sh scripts/localize-*.sh scripts/wait-*.sh scripts/diagnose.sh; do
  echo "=== ShellCheck: $script ==="
  shellcheck -x "$script"
done
```

### 预期结果
- ✓ 所有脚本通过 `bash -n` 语法检查
- ✓ shellcheck 无 error 级别问题（允许 info/warning）

---

## 2. 网络连通性检测

### 测试目标
验证 `check-connectivity.sh` 能准确检测各镜像源可达性。

### 测试命令

```bash
# 运行连通性检测
./scripts/check-connectivity.sh

# 测试不同网络环境
# 1. 正常网络（海外）
# 2. 使用代理
# 3. 断网环境（模拟）
```

### 预期输出示例

```
=== 网络连通性检测 ===

[1/6] Docker 镜像源连通性
  [OK]   Docker Hub (hub.docker.com) — 延迟 150ms
  [SLOW] Google Container Registry (gcr.io) — 延迟 2500ms ⚠️
  [OK]   GitHub Container Registry (ghcr.io) — 延迟 300ms
  [OK]   Quay.io — 延迟 200ms

[2/6] GitHub 访问
  [OK]   GitHub (github.com) — 延迟 180ms
  [OK]   GitHub API — 延迟 200ms

[3/6] 国内镜像源
  [OK]   GCR 镜像 (mirror.gcr.io) — 延迟 50ms
  [OK]   DaoCloud 镜像 — 延迟 80ms
  [OK]   网易镜像 — 延迟 60ms

[4/6] DNS 解析
  [OK]   DNS 解析: docker.io
  [OK]   DNS 解析: github.com
  [OK]   DNS 解析: gcr.io

[5/6] 出站端口
  [OK]   端口 80 开放
  [OK]   端口 443 开放

[6/6] 系统时间
  [OK]   系统时间已同步

=== 检测结果 ===

  OK: 15  SLOW: 1  FAIL: 0

所有服务可达，网络状态良好
```

### 退出码
- `0`: 所有服务可达或仅有慢速源
- `1`: 有不可达源，建议配置镜像加速

---

## 3. Docker 镜像加速配置

### 测试目标
验证 `setup-cn-mirrors.sh` 能正确配置 Docker daemon 镜像源。

### 测试前准备

```bash
# 备份现有配置
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
```

### 测试命令

```bash
# 运行镜像加速配置（需要交互输入 y）
echo "y" | sudo ./scripts/setup-cn-mirrors.sh

# 验证配置文件
cat /etc/docker/daemon.json | jq '.["registry-mirrors"]'

# 验证 Docker info
docker info | grep -A 5 "Registry Mirrors"

# 测试镜像拉取速度
time docker pull hello-world
docker rmi hello-world
```

### 预期结果

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

- ✓ `/etc/docker/daemon.json` 包含镜像源配置
- ✓ `docker info` 显示 Registry Mirrors
- ✓ 镜像拉取速度提升（在中国大陆网络）

### 恢复测试

```bash
# 恢复原始配置
sudo mv /etc/docker/daemon.json.backup /etc/docker/daemon.json
sudo systemctl restart docker
```

---

## 4. 镜像源替换

### 测试目标
验证 `localize-images.sh` 能正确替换 gcr.io/ghcr.io 镜像。

### 测试数据

创建测试 compose 文件：

```bash
cat > /tmp/test-compose.yml <<'EOF'
version: '3.8'
services:
  test-gcr:
    image: gcr.io/google-containers/pause:3.9
  
  test-ghcr:
    image: ghcr.io/goauthentik/server:2024.2
  
  test-quay:
    image: quay.io/prometheus/prometheus:v2.45.0
  
  test-dockerhub:
    image: nginx:alpine
EOF
```

### 测试命令

```bash
# 1. 检查是否需要替换
./scripts/localize-images.sh --check

# 2. 预览变更（dry-run）
./scripts/localize-images.sh --dry-run

# 3. 执行替换
./scripts/localize-images.sh --cn

# 4. 验证替换结果
grep "image:" /tmp/test-compose.yml

# 5. 恢复原始配置
./scripts/localize-images.sh --restore
```

### 预期替换结果

```yaml
# 原始
image: gcr.io/google-containers/pause:3.9
# 替换后
image: gcr.m.daocloud.io/google-containers/pause:3.9

# 原始
image: ghcr.io/goauthentik/server:2024.2
# 替换后
image: ghcr.m.daocloud.io/goauthentik/server:2024.2

# 原始
image: quay.io/prometheus/prometheus:v2.45.0
# 替换后
image: quay.m.daocloud.io/prometheus/prometheus:v2.45.0

# Docker Hub 不替换
image: nginx:alpine  # 保持不变
```

### 验收标准
- ✓ `--check` 正确识别需要替换的镜像
- ✓ `--dry-run` 显示变更但不修改文件
- ✓ `--cn` 替换所有 gcr.io/ghcr.io/quay.io 镜像
- ✓ `--restore` 完整恢复原始文件
- ✓ Docker Hub 镜像不受影响

---

## 5. 安装脚本鲁棒性

### 测试目标
验证 `install.sh` 的各项鲁棒性检查。

### 测试场景

#### 5.1 系统资源检查

```bash
# 模拟低内存环境（需要虚拟机）
# 在 1GB 内存的 VM 上运行
./install.sh

# 预期：显示内存不足警告，询问是否继续
```

#### 5.2 磁盘空间检查

```bash
# 创建大文件占用磁盘空间
dd if=/dev/zero of=/tmp/bigfile bs=1G count=100

# 运行安装
./install.sh

# 预期：显示磁盘空间不足警告
# 清理
rm /tmp/bigfile
```

#### 5.3 端口冲突检测

```bash
# 模拟端口占用
python3 -m http.server 80 &
HTTP_PID=$!

# 运行安装
./install.sh

# 预期：检测到端口 80 被占用

# 清理
kill $HTTP_PID
```

#### 5.4 Docker 自动安装

```bash
# 在全新 Ubuntu 22.04 上测试
# 1. 卸载 Docker
sudo apt-get remove docker docker-engine docker.io containerd runc

# 2. 运行安装
./install.sh

# 预期：
# - 检测到 Docker 未安装
# - 询问是否自动安装
# - 自动安装 Docker
# - 将用户添加到 docker 组
```

#### 5.5 网络重试机制

```bash
# 模拟网络不稳定
# 可以通过 iptables 或 tc 命令模拟

# 验证 curl_retry 函数
# 查看 install.sh 中的实现
grep -A 15 "curl_retry()" install.sh
```

### 预期结果
- ✓ 内存不足时显示警告
- ✓ 磁盘空间不足时显示警告或阻止安装
- ✓ 端口冲突时提示用户
- ✓ 自动安装 Docker 成功
- ✓ 网络失败时自动重试（最多 3 次）

---

## 6. 容器健康等待

### 测试目标
验证 `wait-healthy.sh` 能正确等待容器健康。

### 测试数据

```bash
# 创建测试 stack
cat > /tmp/health-test.yml <<'EOF'
version: '3.8'
services:
  healthy-service:
    image: nginx:alpine
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 2s
      timeout: 1s
      retries: 3
      start_period: 2s
  
  unhealthy-service:
    image: nginx:alpine
    command: ["sh", "-c", "exit 1"]
    healthcheck:
      test: ["CMD", "false"]
      interval: 2s
      timeout: 1s
      retries: 2
EOF

docker compose -f /tmp/health-test.yml up -d
```

### 测试命令

```bash
# 1. 测试健康等待（应该成功）
./scripts/wait-healthy.sh --stack health-test --timeout 30

# 2. 测试不健康容器（应该超时）
# 手动修改 compose 文件使容器失败
# ./scripts/wait-healthy.sh --stack health-test --timeout 20
```

### 预期输出

```
[INFO] 等待 Stack 'health-test' 中所有服务健康...
[INFO] 服务列表: healthy-service unhealthy-service
[INFO] 超时: 30秒

  ✓ healthy-service - 健康
  ○ unhealthy-service - 启动中...

等待中... (5s/30s)

  ✓ healthy-service - 健康
  ✗ unhealthy-service - 不健康

[ERROR] 超时! 等待超过 30秒

=== unhealthy-service (状态: unhealthy) 最近日志 ===
...
```

### 退出码
- `0`: 所有容器健康
- `1`: 超时
- `2`: 有容器退出

---

## 7. 系统诊断

### 测试目标
验证 `diagnose.sh` 能生成完整的诊断报告。

### 测试命令

```bash
# 运行诊断
./scripts/diagnose.sh

# 查看报告
cat diagnose-report.txt

# 验证报告内容
grep -E "系统信息|Docker 信息|容器状态|错误日志|网络信息|配置验证" diagnose-report.txt
```

### 预期报告结构

```
===============================================================================
                    HomeLab Stack 诊断报告
===============================================================================
生成时间: 2026-04-08 15:30:00 CST
主机名: homelab-server
用户: admin

===============================================================================
系统信息
===============================================================================
操作系统: Ubuntu 22.04.3 LTS
内核版本: 5.15.0-91-generic
架构: x86_64
运行时间: up 2 weeks, 3 days, 14:25

CPU:
Model name: Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz
CPU(s): 16
CPU MHz: 3800.000

内存:
              total        used        free      shared  buff/cache   available
Mem:           31Gi       8.2Gi        12Gi       1.1Gi        11Gi        21Gi

磁盘:
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       476G  125G  327G  28% /
/dev/sdb1       916G  450G  420G  52% /var/lib/docker

===============================================================================
Docker 信息
===============================================================================
Docker 版本: Docker version 24.0.7, build afdd53b
Docker Compose 版本: Docker Compose version v2.23.0

Docker 状态: active

Docker 镜像源:
 Registry Mirrors:
  https://docker.m.daocloud.io/
  https://mirror.ccs.tencentyun.com/

===============================================================================
容器状态
==============================================================================
所有容器:
NAMES                    STATUS              PORTS
traefik                  Up 2 weeks          0.0.0.0:80->80/tcp
portainer                Up 2 weeks          0.0.0.0:9000->9000/tcp
prometheus               Up 2 weeks          9090/tcp

===============================================================================
配置验证
===============================================================================
✓ .env 文件存在
  ✓ DOMAIN 已设置
  ✓ ACME_EMAIL 已设置
  ✓ TZ 已设置
✓ acme.json 权限正确 (600)
✓ proxy 网络存在

===============================================================================
                              报告结束
===============================================================================

建议:
1. 如果有容器退出或不健康，检查对应的错误日志
2. 如果网络不可达，考虑运行 ./scripts/setup-cn-mirrors.sh
3. 如果配置验证失败，检查 .env 文件和 acme.json 权限
4. 提交 Issue 时请附带此诊断报告
```

### 验收标准
- ✓ 生成 `diagnose-report.txt` 文件
- ✓ 包含系统信息
- ✓ 包含 Docker 版本和状态
- ✓ 包含容器状态
- ✓ 包含网络连通性测试
- ✓ 包含配置验证结果

---

## 8. 软件包管理器镜像源

### 测试目标
验证 `setup-package-mirrors.sh` 能正确配置 apt/apk 镜像源。

### Ubuntu/Debian 测试

```bash
# 备份原始配置
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 运行配置
echo "y" | sudo ./scripts/setup-package-mirrors.sh

# 验证配置
cat /etc/apt/sources.list

# 测试更新速度
time sudo apt-get update

# 恢复
sudo ./scripts/setup-package-mirrors.sh --restore
```

### Alpine 测试

```bash
# 在 Alpine 容器中测试
docker run -it --rm alpine:3.19 sh

# 在容器内
apk add bash
echo "y" | ./scripts/setup-package-mirrors.sh
cat /etc/apk/repositories
time apk update
```

### 预期结果

**Ubuntu**:
```
# 清华大学开源软件镜像站
# jammy - Generated by homelab-stack setup

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
```

**Alpine**:
```
# 中科大开源镜像站
# Alpine 3.19

https://mirrors.ustc.edu.cn/alpine/v3.19/main
https://mirrors.ustc.edu.cn/alpine/v3.19/community
```

---

## 9. 集成测试

### 完整安装流程测试

```bash
# 1. 检查网络
./scripts/check-connectivity.sh

# 2. 配置 Docker 镜像（如果需要）
sudo ./scripts/setup-cn-mirrors.sh

# 3. 配置软件包镜像（如果需要）
sudo ./scripts/setup-package-mirrors.sh

# 4. 检查依赖
./scripts/check-deps.sh

# 5. 运行安装
./install.sh

# 6. 等待基础服务健康
./scripts/wait-healthy.sh --stack base --timeout 300

# 7. 启动监控
./scripts/stack-manager.sh start monitoring
./scripts/wait-healthy.sh --stack monitoring --timeout 300

# 8. 运行诊断（如有问题）
./scripts/diagnose.sh
```

### 故障恢复测试

```bash
# 1. 模拟故障：停止容器
docker stop traefik

# 2. 运行诊断
./scripts/diagnose.sh

# 3. 查看报告
cat diagnose-report.txt

# 4. 根据报告修复
docker start traefik

# 5. 验证修复
./scripts/wait-healthy.sh --stack base --timeout 60
```

---

## 10. 性能测试

### 镜像拉取速度对比

```bash
# 测试 Docker Hub 镜像
time docker pull nginx:alpine
docker rmi nginx:alpine

# 配置镜像加速后
sudo ./scripts/setup-cn-mirrors.sh
time docker pull nginx:alpine

# 对比两次时间
# 预期：在中国大陆网络环境下，配置后速度提升 2-5 倍
```

### 软件包安装速度对比

```bash
# 测试 apt 速度
time sudo apt-get install -y htop

# 配置镜像源后
sudo ./scripts/setup-package-mirrors.sh
time sudo apt-get install -y htop

# 对比时间
# 预期：在中国大陆网络环境下，配置后速度提升 3-10 倍
```

---

## 11. 回归测试

### 自动化测试脚本

```bash
#!/bin/bash
# test-robustness-features.sh

set -e

echo "=== Robustness Features Regression Test ==="

# Test 1: Script syntax
echo "[1/6] Testing script syntax..."
for script in scripts/setup-*.sh scripts/check-*.sh scripts/localize-*.sh scripts/wait-*.sh scripts/diagnose.sh; do
  bash -n "$script" || { echo "FAIL: $script"; exit 1; }
done
echo "✓ All scripts pass syntax check"

# Test 2: Connectivity check
echo "[2/6] Testing connectivity check..."
./scripts/check-connectivity.sh || echo "Note: Some sources may be unreachable (expected in some networks)"

# Test 3: Localize images
echo "[3/6] Testing image localization..."
./scripts/localize-images.sh --check || echo "Note: Some images may need replacement"

# Test 4: Diagnose
echo "[4/6] Testing diagnostic tool..."
./scripts/diagnose.sh
test -f diagnose-report.txt || { echo "FAIL: diagnose-report.txt not created"; exit 1; }
echo "✓ Diagnostic report generated"

# Test 5: ShellCheck
echo "[5/6] Running ShellCheck..."
if command -v shellcheck >/dev/null; then
  for script in scripts/setup-*.sh scripts/check-*.sh scripts/localize-*.sh scripts/wait-*.sh scripts/diagnose.sh; do
    shellcheck -x "$script" || echo "Warning: $script has shellcheck suggestions"
  done
else
  echo "Skipped: shellcheck not installed"
fi

# Test 6: Help messages
echo "[6/6] Testing help messages..."
for script in scripts/setup-*.sh scripts/localize-*.sh scripts/wait-*.sh; do
  "$script" --help >/dev/null 2>&1 || echo "Note: $script may not support --help"
done

echo ""
echo "=== All tests completed ==="
```

---

## 测试清单

### 功能测试
- [ ] 脚本语法检查通过
- [ ] ShellCheck 无 error
- [ ] 网络连通性检测准确
- [ ] Docker 镜像加速配置成功
- [ ] 软件包镜像源配置成功
- [ ] 镜像源替换功能正常
- [ ] 容器健康等待功能正常
- [ ] 诊断报告生成完整

### 集成测试
- [ ] 完整安装流程无错误
- [ ] 故障诊断和恢复正常
- [ ] 跨平台兼容性（Ubuntu/Debian/Alpine）

### 性能测试
- [ ] 镜像拉取速度提升
- [ ] 软件包安装速度提升
- [ ] 诊断报告生成速度合理

### 文档测试
- [ ] 所有脚本有 --help
- [ ] 所有脚本有注释
- [ ] 文档与实际功能一致

---

## 测试报告模板

```markdown
# Robustness Stack Test Report

**Date**: YYYY-MM-DD
**Tester**: Name
**Environment**: 
  - OS: Ubuntu 22.04 LTS
  - Docker: 24.0.7
  - Network: China Telecom 100Mbps

## Test Results

| Test Case | Status | Notes |
|-----------|--------|-------|
| Script Syntax | ✅ PASS | All scripts pass |
| ShellCheck | ✅ PASS | No errors |
| Connectivity Check | ✅ PASS | 3 slow sources detected |
| Docker Mirror Setup | ✅ PASS | Speed improved 3x |
| Package Mirror Setup | ✅ PASS | Speed improved 5x |
| Image Localization | ✅ PASS | 12 images replaced |
| Health Wait | ✅ PASS | All containers healthy |
| Diagnostics | ✅ PASS | Report generated |

## Issues Found
- None

## Recommendations
- None

## Conclusion
All robustness features work as expected. Ready for production use.
```

---

## 参考资料

- [Bash 最佳实践](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Docker 镜像加速](https://yeasy.gitbook.io/docker_practice/install/mirror)
- [Ubuntu 清华源](https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/)
- [Alpine 中科大源](https://mirrors.ustc.edu.cn/help/alpine.html)
