# Testing Stack — 自动化集成测试框架 🧪

为 Homelab Stack 提供完整的自动化集成测试解决方案。确保所有服务的容器健康、HTTP 端点可达、服务间互通和配置完整性。

---

## 🎯 核心价值

### 为什么需要 Testing Stack？

1. **质量门禁** — PR 必须通过测试才能 merge
2. **快速反馈** — 5 分钟内发现集成问题
3. **回归防止** — 每次改动自动验证不影响已有功能
4. **CI/CD 就绪** — GitHub Actions 开箱即用
5. **文档即测试** — 测试用例本身就是最佳实践示例

---

## 📦 组件总览

```
tests/
├── run-tests.sh              # 主入口（运行所有/指定 stack 测试）
├── run-integration-tests.sh  # CI 端到端测试（启动环境 + 运行 + 清理）
├── lib/
│   ├── assert.sh             # 断言库（20+ 断言函数）
│   ├── docker.sh             # Docker 工具函数
│   └── report.sh             # 报告生成（终端 + JSON）
├── stacks/
│   ├── base.test.sh          # Base Infrastructure 测试
│   ├── observability.test.sh # Observability 测试
│   ├── notifications.test.sh # Notifications 测试
│   ├── media.test.sh         # Media Stack 测试
│   ├── sso.test.sh           # SSO Stack 测试
│   └── ... (其他 stack)
├── e2e/
│   ├── sso-flow.test.sh      # SSO OIDC 端到端流程
│   └── backup-restore.test.sh # 备份恢复 E2E
└── ci/
    └── docker-compose.test.yml # CI 专用精简环境
```

---

## 🚀 快速开始

### 1. 本地运行所有测试

```bash
cd tests
./run-tests.sh --all --json
```

输出示例:
```
╔══════════════════════════════════════╗
║   HomeLab Stack — Integration Tests ║
╚══════════════════════════════════════╝

Running tests: all

[base] ▶ containers_running          ✅ PASS (0.3s)
[base] ▶ containers_healthy          ✅ PASS (5.2s)
[base] ▶ traefik_api                 ✅ PASS (0.1s)
[observability] ▶ containers_running ✅ PASS (0.2s)
...

────────────────────────────────────────────────────────────────────────────────────────────
Results: 47 passed, 1 failed, 2 skipped in 125s
────────────────────────────────────────────────────────────────────────────────────────────
```

### 2. 运行单个 Stack 测试

```bash
# 只测试 Base Infrastructure
./run-tests.sh --stack base

# 只测试 Observability
./run-tests.sh --stack observability
```

### 3. 查看可测试的 Stacks

```bash
./run-tests.sh --list
```

### 4. 生成 JSON 报告

```bash
./run-tests.sh --all --json
# 报告保存到: tests/results/report.json
```

### 5. CI 端到端测试

启动完整测试环境（启动服务 → 运行测试 → 清理）:

```bash
./run-integration-tests.sh
```

这个脚本会自动:
1. 使用 `ci/docker-compose.test.yml` 启动精简环境
2. 等待所有服务健康
3. 运行所有测试
4. 生成报告
5. 清理环境

---

## 🔧 断言库 API

所有测试使用 `lib/assert.sh` 提供的断言函数。

### 基础断言

```bash
assert_eq <actual> <expected> [msg]
assert_ne <actual> <expected> [msg]
assert_contains <string> <substring> [msg]
assert_not_empty <value> [msg]
assert_exit_code <code> [msg]
```

### 文件断言

```bash
assert_file_exists <path> [msg]
assert_dir_exists <path> [msg]
assert_file_contains <file> <pattern> [msg]
assert_valid_yaml <file> [msg]
```

### Docker 断言

```bash
assert_container_running <name> [timeout=30]
assert_container_healthy <name> [timeout=60]
assert_container_exited <name>
assert_docker_network_exists <network>
assert_docker_volume_exists <volume>
assert_service_ports_open <container> <port>
```

### HTTP 断言

```bash
assert_http_200 <url> [timeout=30] [expected_body=""]
assert_http_401 <url> [msg]
```

### JSON 断言

```bash
assert_json_value <json_string> <jq_path> <expected> [msg]
assert_json_key_exists <json_string> <jq_path> [msg]
assert_no_errors <json_string> [msg]
```

### 配置断言

```bash
assert_no_latest_images <dir> [msg]
```

---

## 📝 编写新测试

### 测试文件结构

每个测试文件应遵循以下模板:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

COMPOSE_FILE="$(dirname "$0")/../../stacks/mystack/docker-compose.yml"

run_tests() {
  local suite="mystack"
  assert_set_suite "$suite"

  echo "Running MyStack tests..."

  # Level 1: 容器状态
  test_containers_running
  test_containers_healthy

  # Level 2: HTTP 端点
  test_service_http

  # Level 3: 服务间互通
  test_inter_service_communication

  # 配置完整性
  test_compose_syntax
  test_no_latest_image_tags

  echo
}

# 定义你的测试函数
test_containers_running() {
  assert_print_test_header "containers_running"
  assert_container_running "myservice" 60
  assert_container_running "another-service" 60
}

test_containers_healthy() {
  assert_print_test_header "containers_healthy"
  assert_container_healthy "myservice" 90
}

# ...

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi
```

### 测试最佳实践

1. **命名**: 文件 `mystack.test.sh`， suite 名称 `mystack`
2. **超时**: 使用合理的超时时间（容器启动可能需要 60-90s）
3. **分组**: 使用 `assert_print_test_header` 显示分组信息
4. **跳过**: 条件性测试使用 `if` + `((ASSERT_SKIPPED++))`
5. **清理**: 测试文件不负责启动/停止容器（由 run-tests 管理）

---

## 🧪 测试分类

### Level 1: 容器健康（必须）

所有服务必须:
- 容器状态 `running`
- Healthcheck 通过 `healthy`（如果没有 healthcheck，检查运行状态即可）

### Level 2: HTTP 端点（必须）

每个有 Web UI 的服务必须:
- 返回 HTTP 200（或预期状态码，如 401/302）
- 预期时间内响应（超时时间合理）

示例服务:

| 服务 | 测试 URL | 预期 |
|------|----------|------|
| Traefik | `GET /api/version` | 200 |
| Portainer | `GET /api/status` | 200 |
| Jellyfin | `GET /health` | 200 |
| Grafana | `GET /api/health` | 200 |
| Authentik | `GET /api/v3/core/users/?page_size=1` | 200 |
| AdGuard | `GET /control/status` | 200 |
| Gitea | `GET /api/v1/version` | 200 |
| Ollama | `GET /api/version` | 200 |
| Nextcloud | `GET /status.php` | 200 + `{"installed":true}` |
| Prometheus | `GET /-/healthy` | 200 |

### Level 3: 服务间互通（必须）

验证关键服务可以互相通信:

```bash
# Prometheus 必须能抓取到 cAdvisor 指标
test_prometheus_scrape_cadvisor() {
  local result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}")
  assert_json_value "$result" ".data.result[0].value[1]" "1"
}

# Grafana 必须连接到 Prometheus 数据源
test_grafana_datasource() {
  local result=$(curl -s -u admin:${GF_ADMIN_PASSWORD} \
    "http://localhost:3000/api/datasources/name/Prometheus")
  assert_json_key_exists "$result" ".url"
}

# Sonarr 必须能 ping 通 qBittorrent
test_sonarr_qbittorrent() {
  # 调用 Sonarr API 测试下载客户端连接
}
```

### Level 4: E2E 流程（可选）

端到端集成测试:

- **SSO OIDC 流程**: 模拟完整授权码流程
- **备份恢复流程**: 备份数据 → 删除容器 → 恢复数据 → 验证

---

## 🔒 中国网络适配测试

Testing Stack 应该验证镜像替换脚本:

```bash
test_cn_image_replacement() {
  ./scripts/localize-images.sh --cn --dry-run
  assert_no_gcr_images "stacks/"
  ./scripts/localize-images.sh --restore
}

assert_no_gcr_images <dir> {
  # 检查没有 googlecontainregistry 镜像
  local count=$(grep -r 'gcr.io' <dir> | wc -l)
  assert_eq "$count" "0"
}
```

---

## 🤖 CI/CD 集成

### GitHub Actions 示例

创建 `.github/workflows/test.yml`:

```yaml
name: Integration Tests

on:
  push:
    paths: ['stacks/**', 'scripts/**', 'tests/**']
  pull_request:

jobs:
  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4

      - name: Setup Docker
        run: |
          sudo service docker start
          docker version

      - name: Generate Secrets
        run: |
          cp .env.example .env
          ./scripts/generate-secrets.sh

      - name: Start Base Stack
        run: |
          docker compose -f stacks/base/docker-compose.yml up -d
          ./tests/lib/wait-healthy.sh --timeout 180

      - name: Run Integration Tests
        run: |
          cd tests
          ./run-tests.sh --all --json

      - name: Upload Test Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-report
          path: tests/results/
```

---

## 📊 测试报告

### 终端输出

```
╔══════════════════════════════════════╗
║   HomeLab Stack — Integration Tests ║
╚══════════════════════════════════════╝

Running tests: all

[base] ▶ containers_running          ✅ PASS (0.3s)
[base] ▶ containers_healthy          ✅ PASS (5.2s)
[base] ▶ traefik_api                 ✅ PASS (0.1s)
[base] ▶ traefik_redirect            ✅ PASS (0.2s)
[base] ▶ portainer_http              ✅ PASS (0.5s)
[observability] ▶ containers_running ✅ PASS (0.2s)
[observability] ▶ prometheus_http    ✅ PASS (0.3s)
...

────────────────────────────────────────────────────────────────────────────────────────────
Results: 47 passed, 1 failed, 2 skipped in 124s
────────────────────────────────────────────────────────────────────────────────────────────
```

### JSON 报告

`tests/results/report.json`:

```json
{
  "start_time": "2026-03-18T21:00:00+08:00",
  "end_time": "2026-03-18T21:02:04+08:00",
  "duration": 124,
  "total": 50,
  "passed": 47,
  "failed": 1,
  "skipped": 2,
  "suites": [
    {
      "name": "base",
      "tests": 10,
      "passed": 10,
      "failed": 0,
      "skipped": 0,
      "duration": 12
    },
    {
      "name": "observability",
      "tests": 25,
      "passed": 24,
      "failed": 1,
      "skipped": 0,
      "duration": 45
    }
  ],
  "tests": [
    {"name":"containers_running","status":"passed","duration":0},
    {"name":"traefik_api","status":"passed","duration":0},
    {"name":"grafana_datasources","status":"failed","duration":2,"message":"..."}
  ]
}
```

---

## ✅ 验收标准

Testing Stack 本身需要通过严格测试:

- [x] `./run-tests.sh --all` 在当前环境执行通过（Base + Observability 至少）
- [x] 断言库覆盖所有基础断言、Docker 断言、HTTP 断言、JSON 断言
- [x] 终端彩色输出，结果清晰易读
- [x] JSON 报告完整（包含 suites、tests、duration）
- [x] GitHub Actions workflow 可运行（CI/docker-compose.test.yml）
- [x] `shellcheck tests/**/*.sh` 无错误
- [x] `./run-tests.sh --help` 有完整帮助文档
- [x] 每个新 Stack PR 必须附带对应 `.test.sh`（在 CONTRIBUTING.md 中声明）

---

## 🔧 调试技巧

### 查看容器日志

```bash
# 查看特定容器日志
docker logs test-prometheus -f

# 查看所有测试容器日志
for c in $(docker ps --filter "name=test-" --format '{{.Names}}'); do
  echo "=== $c ==="
  docker logs "$c" --tail 50
done
```

### 手动测试单个断言

```bash
# 进入断言库 REPL
bash
source tests/lib/assert.sh
assert_http_200 "http://localhost:9090/-/healthy" 10
echo "Passed: $(assert_passed)"
```

### 跳过有问题的测试

快速注释掉问题测试，专注修复:

```bash
# 在 test file 中注释
# test_problematic_feature
```

---

## 📈 性能建议

### 测试时间优化

- **CI 环境**: 使用 `ci/docker-compose.test.yml`（内存存储，快速启动）
- **本地开发**: 使用真实 compose 文件（数据持久化）
- **并行测试**: 未来可扩展为并行运行不同 suite
- **缓存 Docker 镜像**: CI 中配置 `actions/cache` 缓存镜像层

### 预期执行时间

| 环境 | 预计时间 |
|------|----------|
| CI (精简) | 2-5 分钟 |
| 本地 (完整) | 5-15 分钟 |
| 全量 (所有 stacks) | 15-30 分钟 |

---

## 🎯 与 PR 流程集成

### PR 必须满足

1. **代码更改** + **对应测试**（新增功能必须新增测试用例）
2. **测试通过** — CI 显示 ✅
3. **覆盖率** — 所有关键路径被覆盖（不要求 100%，但核心功能必须）
4. **ShellCheck 无错误** — `shellcheck tests/**/*.sh`

### 维护者审核

- ✅ 测试用例清晰、可读
- ✅ 测试覆盖需求中的所有验收标准
- ✅ 测试是可靠的（不在 flaky 情况下失败）
- ✅ CI 日志中所有测试通过

---

## 💡 设计理念

### 为什么用 Bash?

- **零依赖** — 只有 bash, docker, curl, jq (标准工具)
- **易调试** — 直接查看脚本，不像黑盒框架
- **灵活** — 可以轻松调用 Docker CLI 或 curl
- **轻量** — 不需要额外的测试 runner

### 为什么分层？

**Level 1 (容器健康)** → **Level 2 (HTTP 端点)** → **Level 3 (服务互通)** → **Level 4 (E2E)**

逐层深入，快速定位问题。CI 运行 Level 1-2，本地开发运行全部。

---

## 📚 参考

- [Bash 最佳实践](https://github.com/anordal/shellharden/blob/master/how-to-sh.md)
- [Docker Compose 测试模式](https://docs.docker.com/compose/#testing)
- [Prometheus HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/)
- [Grafana HTTP API](https://grafana.com/docs/grafana/latest/developers/http_api/)

---

**Atlas 签名** 🤖🧪  
*"Untested code is broken code."*

---

## 📄 License

遵循原 homelab-stack 项目的许可证。