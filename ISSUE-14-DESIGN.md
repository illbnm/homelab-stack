# Issue #14 技术设计方案 — Integration Testing ($200 USDT)

> 状态: 草稿 v1.0 | 负责人: achieve07 | 协作: research

---

## 📋 需求分析

Issue #14 要求实现完整的集成测试套件，验证 HomeLab Stack 所有服务。

### 关键约束
- **纯 Bash**：无额外框架依赖（curl, jq, docker, docker compose v2）
- **零外部依赖**：shellcheck 通过即可运行
- **双输出**：终端彩色 + JSON 报告
- **CI 就绪**：GitHub Actions workflow

### 已实现 vs 待实现

| 组件 | 状态 | 位置 |
|------|------|------|
| tests/ 目录结构 | ✅ 存在 | tests/{lib,stacks,e2e,results}/ |
| run-tests.sh | ❌ 待实现 | tests/run-tests.sh |
| lib/assert.sh | ❌ 待实现 | tests/lib/assert.sh |
| lib/docker.sh | ❌ 待实现 | tests/lib/docker.sh |
| lib/report.sh | ❌ 待实现 | tests/lib/report.sh |
| stacks/*.test.sh | ❌ 待实现 | 10个stack测试文件 |
| e2e/*.test.sh | ❌ 待实现 | SSO + backup e2e |
| ci/docker-compose.test.yml | ❌ 待实现 | CI专用compose |
| .github/workflows/test.yml | ❌ 待实现 | CI配置 |

---

## 🏗️ 架构设计

### 目录结构

```
tests/
├── run-tests.sh              # 主入口，支持 --stack <name> / --all / --e2e
├── lib/
│   ├── assert.sh             # 断言库 (12个函数)
│   ├── docker.sh             # Docker工具函数 (container_status, wait_healthy等)
│   ├── report.sh             # 彩色输出 + JSON报告
│   └── wait-healthy.sh       # 等待服务健康脚本
├── stacks/
│   ├── base.test.sh          # Traefik, Portainer, Watchtower
│   ├── media.test.sh         # Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent
│   ├── storage.test.sh       # Nextcloud, MinIO, FileBrowser, Syncthing
│   ├── monitoring.test.sh    # Prometheus, Grafana, Loki, Alertmanager, Uptime Kuma
│   ├── network.test.sh       # AdGuard, WireGuard, Nginx Proxy Manager
│   ├── productivity.test.sh  # Gitea, Vaultwarden, Outline, Stirling-PDF
│   ├── ai.test.sh            # Ollama, Open WebUI, LocalAI, n8n
│   ├── home-automation.test.sh  # Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT
│   ├── sso.test.sh           # Authentik, PostgreSQL, Redis
│   ├── databases.test.sh     # PostgreSQL, Redis, MariaDB, phpMyAdmin
│   └── notifications.test.sh # Gotify, ntfy, Apprise
├── e2e/
│   ├── sso-flow.test.sh      # OIDC完整登录流程
│   └── backup-restore.test.sh # 备份恢复端到端
├── ci/
│   └── docker-compose.test.yml # CI环境（无需真实域名）
└── results/
    └── report.json           # 测试报告输出
```

---

## 🔧 核心模块设计

### 1. lib/assert.sh — 断言库

```bash
# 12个核心断言函数
assert_eq()              # 相等比较
assert_not_eq()          # 不等比较
assert_contains()        # 字符串包含
assert_not_empty()       # 非空检查
assert_exit_code()       # 退出码检查
assert_http_200()        # HTTP 200检查（支持timeout）
assert_http_response()    # HTTP响应匹配模式
assert_json_value()      # JSON字段值验证（jq）
assert_json_key_exists() # JSON字段存在性
assert_no_errors()       # JSON错误检查
assert_file_contains()   # 文件内容检查
assert_no_latest_images() # Compose无:latest标签
```

### 2. lib/docker.sh — Docker工具

```bash
container_status()        # 获取容器状态（running/exited/paused）
container_health()        # 获取健康状态（healthy/unhealthy/starting）
wait_for_healthy()        # 等待容器健康（最多60s）
is_container_running()    # 容器运行检查
get_container_ip()        # 获取容器IP
exec_in_container()       # 在容器内执行命令
```

### 3. lib/report.sh — 输出报告

```bash
report_start()            # 测试开始横幅
report_pass()             # ✅ PASS 输出（彩色）
report_fail()             # ❌ FAIL 输出（彩色+原因）
report_skip()             # ⏭️ SKIP 输出
report_summary()          # 最终汇总（passed/failed/skipped/duration）
generate_json_report()    # 写入 tests/results/report.json
```

### 4. run-tests.sh — 主入口

```bash
# 支持的选项
--stack <name>    # 只测试指定stack（base/media/storage/...）
--all             # 测试所有stack（默认）
--e2e             # 只运行端到端测试
--json            # 输出JSON报告
--verbose         # 详细输出
--help            # 帮助文档
```

---

## 📊 测试覆盖分层

### Level 1 — 容器健康（必须）
每个服务：容器运行状态 + 健康检查

### Level 2 — HTTP端点（必须）
每个有Web UI的服务：GET健康端点 → 期望200

### Level 3 — 服务互通（必须）
跨服务通信：Prometheus→cAdvisor, Grafana→Prometheus等

### Level 4 — E2E（SSO+Backup）
完整用户流程：OIDC登录 + 备份恢复

### Level 5 — 配置完整性（必须）
Compose语法 + 无:latest标签 + healthcheck存在性

### Level 6 — CN网络适配（可选）
镜像替换脚本 + Docker镜像加速配置

---

## ✅ 验收标准映射

| 标准 | 实现文件 | 验证方式 |
|------|---------|---------|
| run-tests.sh --stack base 通过 | run-tests.sh | 全新环境执行 |
| run-tests.sh --all 通过 | 10×stacks/*.test.sh | CI执行 |
| 断言库完整 | lib/assert.sh | 12函数全部实现 |
| 彩色+JSON双输出 | lib/report.sh | 人工验证 |
| GitHub Actions workflow | .github/workflows/test.yml | CI运行验证 |
| --help 文档 | run-tests.sh -h | 人工验证 |
| shellcheck无error | 所有*.sh | `shellcheck *.sh` |

---

## 🔒 质量工具链建议（回应Research）

### 1. 代码注释规范 — JSDoc/BashDoc强制检查
```bash
# 所有公共函数顶部必须有以下注释块：
#!/bin/bash
# =============================================================================
# Function: assert_http_200
# Description: 检查HTTP端点返回200状态码
# Usage: assert_http_200 <url> [timeout=30]
# Returns: 0=pass, 1=fail
# Example: assert_http_200 "http://localhost:9000/api/status"
# =============================================================================

# ShellCheck扫描（CI强制）
# .github/workflows/test.yml 添加：
- name: Lint bash
  run: |
    for f in tests/**/*.sh; do
      shellcheck --severity=error "$f"
    done
```

### 2. Commit Message标准化
```
feat(<stack>): <简短描述> (<issue> $<bounty>)
feat(tests): add assert_http_200 with timeout support (#14 $200)
fix(databases): resolve postgres healthcheck interval (#11 $130)
```

### 3. 测试覆盖率要求 ≥85%
```bash
# 每个stack测试文件至少覆盖：
- Level 1: 容器运行检查（3项/栈）
- Level 2: HTTP端点检查（每个Web服务1项）
- Level 3: 服务互通（每个跨栈通信1项）
- Level 5: 配置完整性（3项全局）

# 覆盖率计算：
# = (实际测试项 / 理论最大测试项) × 100%
# 10 stacks × (3+5+3+3) = 140项基础
# 目标: 120项+ = 85%+
```

---

## 📅 执行计划

| 时间 | 任务 | 产出 |
|------|------|------|
| 10:20-11:30 | 核心库实现：assert.sh, docker.sh, report.sh | 3个lib文件 |
| 11:30-12:30 | 主入口：run-tests.sh + CI workflow | 2个文件 |
| 12:30-13:00 | 前3个stack测试：base, network, databases | 3个.test.sh |
| 13:00-14:00 | 后7个stack测试 + e2e | 9个文件 |
| 14:00-15:00 | 本地验证 + shellcheck修复 | 通过CI |

**关键路径**: run-tests.sh + assert.sh 是其他所有测试的前置依赖。

---

## 💰 赏金关联

- Issue #14: $200 USDT（Integration Testing）
- 交付物完整度直接影响批准率
- 先实现再优化，确保80%覆盖率优先
