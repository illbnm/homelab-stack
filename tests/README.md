# HomeLab Stack — Integration Test Suite

自动化集成测试框架，验证所有 HomeLab Stack 服务的正确性。

## 快速开始

```bash
# 运行所有测试
./tests/run-tests.sh

# 只测试某个栈
./tests/run-tests.sh --stack base
./tests/run-tests.sh --stack media,monitoring,databases

# CI 模式（失败即停 + JSON 输出）
./tests/run-tests.sh --ci

# 快速模式（跳过 e2e 测试）
./tests/run-tests.sh --quick

# 查看可用测试套件
./tests/run-tests.sh --list

# 干跑（只显示会执行什么）
./tests/run-tests.sh --dry-run
```

## 目录结构

```
tests/
├── run-tests.sh              # 测试入口
├── README.md                 # 本文件
├── lib/
│   ├── assert.sh             # 断言库
│   ├── docker.sh             # Docker 工具函数
│   └── report.sh             # 结果输出 (JSON + 终端)
├── stacks/
│   ├── base.test.sh          # 基础设施测试
│   ├── media.test.sh         # 媒体栈测试
│   ├── storage.test.sh       # 存储栈测试
│   ├── monitoring.test.sh    # 监控栈测试
│   ├── network.test.sh       # 网络栈测试
│   ├── productivity.test.sh  # 生产力工具测试
│   ├── ai.test.sh            # AI 栈测试
│   ├── sso.test.sh           # SSO 测试
│   ├── databases.test.sh     # 数据库测试
│   ├── notifications.test.sh # 通知测试
│   ├── home-automation.test.sh # 智能家居测试
│   └── dashboard.test.sh     # 仪表盘测试
├── e2e/
│   ├── sso-flow.test.sh      # SSO 端到端流程测试
│   └── backup-restore.test.sh # 备份恢复测试
├── ci/
│   └── docker-compose.test.yml # CI 专用轻量 compose
└── results/                  # 测试结果 JSON（自动生成）
```

## 测试分层

### Level 1 — 容器健康测试（必须）
- 容器运行状态
- 健康检查通过
- 镜像版本锁定（非 `latest`）
- 重启策略正确

### Level 2 — HTTP 端点测试（必须）
- 每个 Web UI 服务的 HTTP 可达性
- API 端点返回正确状态码
- JSON 响应体验证

### Level 3 — 服务间互通测试（必须）
- 容器间网络连通性
- Prometheus 抓取目标验证
- 数据库连接验证

### Level 4 — 端到端测试（推荐）
- SSO 完整认证流程
- 备份创建与验证

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BASE_URL` | `http://localhost` | 服务基础 URL |
| `FAIL_FAST` | `0` | 遇到失败立即停止 |
| `TEST_TIMEOUT` | `120` | 每个栈的超时秒数 |

## 输出

测试完成后会生成：
- **终端输出**：彩色通过/失败/跳过统计
- **JSON 报告**：`tests/results/test-results-YYYYMMDD-HHMMSS.json`

### JSON 报告格式

```json
{
  "timestamp": "2026-05-21T10:30:00Z",
  "duration_seconds": 42,
  "summary": {
    "total": 85,
    "passed": 80,
    "failed": 2,
    "skipped": 3
  },
  "results": [
    {
      "suite": "Base Infrastructure",
      "test": "container:traefik:running",
      "status": "pass",
      "message": "running"
    }
  ]
}
```

## 编写新测试

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

# 选择性运行
should_run_stack "mystack" || exit 0

begin_suite "My Stack"

# 容器测试
assert_container_running "my-container"
assert_container_healthy "my-container"
assert_container_not_latest "my-container"

# HTTP 测试
assert_http_200 "http://localhost:8080/api/health" "my-api"

# 端口测试
assert_port_open "localhost" "5432" "my-db"

# 自定义测试
begin_test "my_custom_check"
if some_condition; then
  assert_pass "it works"
else
  assert_fail "it broke"
fi
```

## 依赖

- `bash` 4.0+
- `docker` + `docker compose`
- `curl`
- `nc` (netcat)
- `python3` (用于 JSON 解析)
