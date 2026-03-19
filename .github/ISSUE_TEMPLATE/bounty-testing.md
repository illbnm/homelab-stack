---
name: 💰 Bounty - Integration Testing
about: 实现完整的集成测试套件，验证所有服务正常运行
title: '[BOUNTY $280] Integration Testing — 全栈集成测试'
labels: bounty, testing, hard
assignees: ''
---

## 赏金金额

**$280 USDT** (或等值法币)

> ⚠️ 此任务优先级最高 — 没有测试，其他任务的交付物无法验收。

## 任务描述

编写自动化集成测试套件，验证 HomeLab Stack 中所有服务的：
- 容器启动状态
- 健康检查
- HTTP 端点可达性
- 服务间互通
- 配置完整性

## 文件结构

```
tests/
├── run-tests.sh              # 测试入口，支持 --stack <name> 或 --all
├── lib/
│   ├── assert.sh             # 断言库 (assert_eq, assert_http_200, etc.)
│   ├── docker.sh             # Docker 工具函数
│   └── report.sh             # 结果输出 (JSON + 终端彩色)
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
└── ci/
    └── docker-compose.test.yml # CI 专用 compose (无需真实域名)
```

## 测试分类

### 1. 容器健康测试 (Level 1 — 必须)

```bash
# 示例：base.test.sh
test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_http_200 "http://localhost:9000"
}

test_watchtower_running() {
  assert_container_running "watchtower"
}
```

### 2. HTTP 端点测试 (Level 2 — 必须)

每个有 Web UI 的服务必须测试：

| 服务 | 测试 | 预期 |
|------|------|------|
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

### 3. 服务间互通测试 (Level 3 — 必须)

```bash
# Prometheus 必须能抓取到 cAdvisor 指标
test_prometheus_scrape_cadvisor() {
  local result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}")
  assert_json_value "$result" ".data.result[0].value[1]" "1"
}

# Grafana 必须连接到 Prometheus 数据源
test_grafana_prometheus_datasource() {
  local result=$(curl -s -u admin:${GF_ADMIN_PASSWORD} \
    "http://localhost:3000/api/datasources/name/Prometheus")
  assert_json_key_exists "$result" ".url"
}

# Sonarr 必须能 ping 通 qBittorrent
test_sonarr_qbittorrent_connection() {
  local result=$(curl -s -X POST \
    -H "X-Api-Key: ${SONARR_API_KEY}" \
    "http://localhost:8989/api/v3/downloadclient/test" \
    -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}')
  assert_no_errors "$result"
}
```

### 4. SSO 流程测试 (Level 4 — E2E)

```bash
# sso-flow.test.sh
# 使用 curl 模拟完整 OIDC 授权码流程
test_sso_grafana_login() {
  # 1. 访问 Grafana → 302 跳转 Authentik
  # 2. 提交用户名密码 → 获取 code
  # 3. 用 code 换 token
  # 4. 确认 Grafana 返回 200
}
```

### 5. 配置完整性测试 (Level 1 — 必须)

```bash
# 检查所有 compose 文件语法
test_compose_syntax() {
  for f in $(find stacks -name 'docker-compose.yml'); do
    docker compose -f "$f" config --quiet 2>&1
    assert_exit_code 0 "$f compose config failed"
  done
}

# 检查所有镜像 tag 非 latest
test_no_latest_tags() {
  local count=$(grep -r 'image:.*:latest' stacks/ | wc -l)
  assert_eq "$count" "0" "Found :latest image tags"
}

# 检查所有服务有 healthcheck
test_all_services_have_healthcheck() {
  # 解析每个 compose.yml，验证每个 service 有 healthcheck
}
```

### 6. 中国网络适配测试 (Level 2)

```bash
# 验证镜像替换脚本正确性
test_cn_image_replacement() {
  ./scripts/localize-images.sh --cn --dry-run
  assert_no_gcr_images "stacks/"
  ./scripts/localize-images.sh --restore
}

# 验证镜像加速配置写入正确
test_docker_mirror_config() {
  ./scripts/setup-cn-mirrors.sh --dry-run
  assert_file_contains "/tmp/daemon.json.test" "registry-mirrors"
}
```

## 断言库规范

`tests/lib/assert.sh` 必须实现：

```bash
assert_eq <actual> <expected> [msg]
assert_not_empty <value> [msg]
assert_exit_code <code> [msg]
assert_container_running <name>
assert_container_healthy <name>         # 等待最多 60s
assert_http_200 <url> [timeout=30]
assert_http_response <url> <pattern>    # grep -q
assert_json_value <json> <jq_path> <expected>
assert_json_key_exists <json> <jq_path>
assert_no_errors <json>                 # .errors 为空
assert_file_contains <file> <pattern>
assert_no_latest_images <dir>           # 扫描 compose 文件
```

## 测试输出格式

终端输出：
```
╔══════════════════════════════════════╗
║   HomeLab Stack — Integration Tests  ║
╚══════════════════════════════════════╝

[base] ▶ Traefik running          ✅ PASS (0.3s)
[base] ▶ Portainer HTTP 200       ✅ PASS (1.2s)
[base] ▶ Watchtower running       ✅ PASS (0.1s)
[media] ▶ Jellyfin running        ✅ PASS (2.1s)
[media] ▶ Sonarr API /v3          ✅ PASS (0.8s)
[sso]  ▶ Authentik OIDC flow      ❌ FAIL (5.0s)
       Expected: 200, Got: 502

──────────────────────────────────────
Results: 47 passed, 1 failed, 2 skipped
Duration: 124s
──────────────────────────────────────
```

JSON 报告同时写入 `tests/results/report.json`。

## CI 集成

`.github/workflows/test.yml`：

```yaml
name: Integration Tests
on:
  push:
    paths: ['stacks/**', 'scripts/**']
  pull_request:

jobs:
  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: Setup
        run: |
          cp .env.example .env
          ./scripts/generate-secrets.sh
      - name: Start base stack
        run: docker compose -f stacks/base/docker-compose.yml up -d
      - name: Wait for healthy
        run: ./tests/lib/wait-healthy.sh --timeout 120
      - name: Run tests
        run: ./tests/run-tests.sh --stack base --json
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: test-report
          path: tests/results/
```

## 验收标准

- [ ] `tests/run-tests.sh --stack base` 在全新环境执行通过
- [ ] `tests/run-tests.sh --all` 对所有已实现 stack 执行通过
- [ ] 断言库覆盖上述所有方法
- [ ] 终端彩色输出 + JSON 报告双输出
- [ ] GitHub Actions workflow 配置完整，可在 CI 中运行
- [ ] `tests/run-tests.sh --help` 有完整帮助文档
- [ ] 测试脚本通过 `shellcheck` 无 error
- [ ] 每个新 Stack PR 必须附带对应 `.test.sh`（在 CONTRIBUTING.md 中说明）

## 依赖

- `curl`, `jq`, `docker`, `docker compose` (v2)
- 无额外框架依赖（纯 bash）

## 认领方式

在下方评论 "我来认领"，并说明你的测试框架经验。

## 支付

验收通过后 3 个工作日内支付。
