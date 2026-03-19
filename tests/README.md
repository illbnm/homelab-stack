# HomeLab Stack Integration Tests

集成测试套件，验证 HomeLab Stack 中所有服务的正常运行。

## 目录结构

```
tests/
├── run-tests.sh              # 测试入口脚本
├── README.md                 # 本文档
├── lib/
│   ├── assert.sh             # 断言库
│   ├── docker.sh             # Docker 工具函数
│   ├── report.sh             # 结果输出 (JSON + 终端彩色)
│   └── wait-healthy.sh       # 等待容器健康
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
│   └── notifications.test.sh # 通知测试
├── e2e/
│   ├── sso-flow.test.sh      # SSO 完整登录流程端到端测试
│   └── backup-restore.test.sh # 备份恢复端到端测试
└── results/
    └── *.json                # 测试报告
```

## 快速开始

### 运行单个 Stack 测试

```bash
# 运行 base stack 测试
./tests/run-tests.sh --stack base

# 运行 media stack 测试
./tests/run-tests.sh --stack media
```

### 运行所有测试

```bash
./tests/run-tests.sh --all
```

### 输出 JSON 报告

```bash
./tests/run-tests.sh --stack base --json
```

### 查看帮助

```bash
./tests/run-tests.sh --help
```

## 可用 Stack

| Stack | 描述 | 主要服务 |
|-------|------|----------|
| `base` | 基础设施 | Traefik, Portainer, Watchtower |
| `media` | 媒体栈 | Jellyfin, Sonarr, Radarr, qBittorrent |
| `storage` | 存储栈 | Nextcloud, Samba, Syncthing |
| `monitoring` | 监控栈 | Grafana, Prometheus, Alertmanager, cAdvisor |
| `network` | 网络栈 | AdGuard, Pi-hole, WireGuard |
| `productivity` | 生产力工具 | Gitea, n8n, Paperless |
| `ai` | AI 栈 | Ollama, Open WebUI, LocalAI |
| `sso` | SSO | Authentik |
| `databases` | 数据库 | PostgreSQL, MySQL, MongoDB, Redis |
| `notifications` | 通知 | Gotify, ntfy, Apprise |

## 断言库

`tests/lib/assert.sh` 提供以下断言函数：

### 基础断言

- `assert_eq <actual> <expected> [msg]` - 检查值相等
- `assert_not_empty <value> [msg]` - 检查值非空
- `assert_exit_code <code> [msg]` - 检查退出码

### Docker 断言

- `assert_container_running <name>` - 检查容器运行中
- `assert_container_healthy <name> [timeout]` - 检查容器健康（默认 60s）

### HTTP 断言

- `assert_http_200 <url> [timeout]` - 检查 HTTP 200 响应
- `assert_http_response <url> <pattern> [timeout]` - 检查响应包含模式

### JSON 断言

- `assert_json_value <json> <jq_path> <expected>` - 检查 JSON 值
- `assert_json_key_exists <json> <jq_path>` - 检查 JSON 键存在
- `assert_no_errors <json>` - 检查 JSON 无错误

### 文件断言

- `assert_file_exists <file>` - 检查文件存在
- `assert_file_contains <file> <pattern>` - 检查文件包含模式
- `assert_no_latest_images <dir>` - 检查无 :latest 镜像标签

## 测试输出

### 终端输出

```
╔══════════════════════════════════════╗
║   HomeLab Stack — Base Tests         ║
╚══════════════════════════════════════╝

[base] ▶ Traefik running          ✅ PASS (0.3s)
[base] ▶ Portainer HTTP 200       ✅ PASS (1.2s)
[base] ▶ Watchtower running       ✅ PASS (0.1s)

──────────────────────────────────────
Results: ✅ 47 passed, ❌ 1 failed, ⏭️ 2 skipped
Total: 50
──────────────────────────────────────
```

### JSON 报告

测试报告自动写入 `tests/results/report_YYYYMMDD_HHMMSS.json`：

```json
{
  "timestamp": "2026-03-19T05:30:00Z",
  "stack": "base",
  "duration": 124,
  "summary": {
    "total": 50,
    "passed": 47,
    "failed": 1,
    "skipped": 2
  },
  "tests": [...]
}
```

## CI 集成

GitHub Actions workflow 已配置在 `.github/workflows/test.yml`。

### 本地验证

在提交 PR 前，本地运行：

```bash
# 1. 验证所有测试脚本语法
for f in tests/**/*.sh; do bash -n "$f"; done

# 2. 验证 compose 文件语法
for f in $(find stacks -name 'docker-compose.yml'); do
  docker compose -f "$f" config --quiet
done

# 3. 检查无 :latest 标签
grep -r 'image:.*:latest' stacks/ && exit 1

# 4. 运行测试
./tests/run-tests.sh --stack base
```

## 等待容器健康

使用 `wait-healthy.sh` 脚本等待容器启动：

```bash
# 等待 base stack 容器
./tests/lib/wait-healthy.sh --stack base --timeout 120

# 等待所有容器
./tests/lib/wait-healthy.sh --all --timeout 180
```

## 依赖

- `bash` (v4.0+)
- `docker` (v20.10+)
- `docker compose` (v2.0+)
- `curl`
- `jq`

## 新增 Stack 测试

为新的 Stack 添加测试：

1. 在 `tests/stacks/` 创建 `<stack>.test.sh`
2. 实现 `run_<stack>_tests()` 函数
3. 使用断言库编写测试用例
4. 在 `run-tests.sh` 的 `run_all_tests()` 中添加 stack 名称

### 示例

```bash
#!/bin/bash
# myservice.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"

test_myservice_running() {
    assert_container_running "myservice"
}

test_myservice_http() {
    assert_http_200 "http://localhost:8080"
}

run_myservice_tests() {
    print_header "MyService Tests"
    test_myservice_running || true
    test_myservice_http || true
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_myservice_tests
fi
```

## 故障排查

### 容器未运行

```bash
# 检查容器状态
docker ps -a | grep <container>

# 查看容器日志
docker logs <container>
```

### HTTP 测试失败

```bash
# 手动测试端点
curl -v http://localhost:8080

# 检查端口监听
netstat -tlnp | grep 8080
```

### JSON 解析错误

```bash
# 验证 jq 路径
curl -s http://localhost:8080/api | jq '.key'
```

## 贡献指南

- 每个新 Stack PR 必须附带对应 `.test.sh`
- 测试脚本必须通过 `shellcheck` 无 error
- 所有测试必须支持 `--help` 输出帮助
- 终端输出必须彩色，同时生成 JSON 报告
