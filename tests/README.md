# tests/README.md — 测试套件说明

## 目录结构

```
tests/
├── run-tests.sh              # 入口，支持 --stack <name> 或 --all
├── lib/
│   ├── assert.sh             # 断言库（20+ 断言方法）
│   ├── docker.sh             # Docker 工具函数
│   └── report.sh             # 输出格式化（彩色 + JSON）
├── stacks/                   # 各 stack 测试
│   ├── base.test.sh
│   ├── databases.test.sh
│   ├── media.test.sh
│   ├── monitoring.test.sh
│   ├── network.test.sh
│   ├── notifications.test.sh
│   └── ...
├── e2e/                      # 端到端测试
└── ci/                       # CI 配置
```

## 使用方法

```bash
# 测试单个 stack
./tests/run-tests.sh --stack base

# 测试所有 stack
./tests/run-tests.sh --all

# 输出 JSON 报告
./tests/run-tests.sh --all --json
```

## 断言库 API

| 方法 | 说明 |
|------|------|
| `assert_eq <a> <b> [msg]` | 相等 |
| `assert_not_empty <val>` | 非空 |
| `assert_exit_code <n>` | 退出码 |
| `assert_container_running <name>` | 容器运行中 |
| `assert_container_healthy <name> [timeout]` | 容器 healthy |
| `assert_http_200 <url> [timeout]` | HTTP 200 |
| `assert_http_status <url> <code>` | HTTP 状态码 |
| `assert_http_response <url> <pattern>` | HTTP 响应包含 |
| `assert_json_value <json> <jq> <expected>` | JSON 值 |
| `assert_json_key_exists <json> <jq>` | JSON key 存在 |
| `assert_file_contains <file> <pattern>` | 文件包含 |
| `assert_no_latest_images <dir>` | 无 :latest tag |

## Level 说明

- **Level 1（必须）**: 容器运行 + healthcheck + compose 语法
- **Level 2（必须）**: HTTP 端点可达性
- **Level 3（尽力）**: 服务间互通（Prometheus scrape、Grafana datasource 等）
- **Level 4（E2E）**: 完整业务流程（SSO 登录流、备份恢复）
