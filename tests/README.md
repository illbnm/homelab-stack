# HomeLab Stack Integration Tests

完整的集成测试套件，验证 HomeLab Stack 中所有服务的正常运行。

## 快速开始

```bash
# 运行基础栈测试
./tests/run-tests.sh --stack base

# 运行所有测试
./tests/run-tests.sh --all

# 运行测试并生成 JSON 报告
./tests/run-tests.sh --all --json

# 运行测试并生成 JUnit 报告 (用于 CI)
./tests/run-tests.sh --stack base --junit
```

## 文件结构

```
tests/
├── run-tests.sh              # 测试入口脚本
├── lib/
│   ├── assert.sh             # 断言库
│   ├── docker.sh             # Docker 工具函数
│   ├── report.sh             # 报告生成
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
│   ├── notifications.test.sh # 通知测试
│   └── cn-adaptation.test.sh # 中国网络适配测试
├── e2e/
│   ├── sso-flow.test.sh      # SSO 端到端测试
│   └── backup-restore.test.sh# 备份恢复测试
├── ci/
│   └── docker-compose.test.yml # CI 专用配置
└── results/                   # 测试报告输出目录
```

## 断言库

`lib/assert.sh` 提供以下断言函数：

| 函数 | 说明 |
|------|------|
| `assert_eq <actual> <expected>` | 检查值相等 |
| `assert_not_empty <value>` | 检查值非空 |
| `assert_exit_code <code> <command>` | 检查命令退出码 |
| `assert_container_running <name>` | 检查容器运行 |
| `assert_container_healthy <name>` | 检查容器健康 (等待最多 60s) |
| `assert_http_200 <url>` | 检查 HTTP 200 响应 |
| `assert_http_response <url> <pattern>` | 检查 HTTP 响应包含模式 |
| `assert_json_value <json> <path> <expected>` | 检查 JSON 值 |
| `assert_json_key_exists <json> <path>` | 检查 JSON 键存在 |
| `assert_no_errors <json>` | 检查无错误 |
| `assert_file_contains <file> <pattern>` | 检查文件包含模式 |
| `assert_no_latest_images <dir>` | 检查无 :latest 标签 |
| `assert_compose_valid <file>` | 检查 Compose 文件语法 |

## 测试分类

### Level 1 - 容器健康测试 (必须)
- 容器运行状态
- 健康检查状态
- Compose 文件语法验证
- 无 :latest 镜像标签

### Level 2 - HTTP 端点测试 (必须)
- 所有 Web UI 服务的 HTTP 可达性
- API 端点响应验证

### Level 3 - 服务间互通测试 (必须)
- Prometheus 抓取 cAdvisor 指标
- Grafana 连接 Prometheus 数据源
- 服务间 API 调用

### Level 4 - E2E 流程测试
- SSO 完整登录流程
- 备份恢复流程

### 中国网络适配测试
- 镜像替换脚本验证
- Docker 镜像加速配置

## 输出格式

### 终端输出
```
╔════════════════════════════════════════════╗
║  HomeLab Stack — Integration Tests         ║
╚════════════════════════════════════════════╝

════════════════════════════════════════
Stack: base
════════════════════════════════════════
[base] ▶ traefik running ✅ PASS (0.3s)
[base] ▶ traefik healthy ✅ PASS (1.2s)
[base] ▶ HTTP 200 http://localhost:8080/api/version ✅ PASS (0.5s)

──────────────────────────────────────────────────
Results:
  ✅ 47 passed
  ❌ 1 failed
  📊 Total: 48 tests
  ⏱️  Duration: 124s
──────────────────────────────────────────────────
```

### JSON 报告
```json
{
  "timestamp": "2026-03-25T00:00:00Z",
  "stack": "base",
  "summary": {
    "passed": 47,
    "failed": 1,
    "skipped": 0,
    "total": 48,
    "duration_seconds": 124
  },
  "tests": [...]
}
```

### JUnit XML 报告
用于 CI/CD 集成，支持 GitHub Actions、GitLab CI 等。

## CI 集成

GitHub Actions 示例：

```yaml
name: Integration Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      
      - name: Start base stack
        run: docker compose -f stacks/base/docker-compose.yml up -d
      
      - name: Wait for healthy
        run: ./tests/lib/wait-healthy.sh --timeout 120
      
      - name: Run tests
        run: ./tests/run-tests.sh --stack base --junit
      
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: test-report
          path: tests/results/
```

## 依赖

- `curl` - HTTP 请求
- `jq` - JSON 处理
- `docker` - 容器管理
- `docker compose` (v2) - Compose 管理
- `bash` (v4+) - Shell 环境
- `bc` - 浮点计算

## 最佳实践

1. **每个新 Stack PR 必须附带对应 `.test.sh` 文件**
2. **测试应该幂等** - 可重复运行
3. **超时设置合理** - 避免过长等待
4. **错误信息清晰** - 便于调试
5. **使用健康检查** - 等待服务就绪

## 贡献指南

添加新测试：

1. 在 `tests/stacks/` 创建 `<stack>.test.sh`
2. 实现测试函数，使用 `assert_*` 函数
3. 在 `tests/run-tests.sh` 添加运行入口
4. 运行 `./tests/run-tests.sh --stack <name>` 验证

示例测试函数：

```bash
test_my_service_running() {
    assert_container_running "my-service"
}

test_my_service_http() {
    assert_http_200 "http://localhost:8080/health"
}
```

## 故障排查

### 容器未找到
确保服务已启动：
```bash
docker compose -f stacks/<stack>/docker-compose.yml up -d
```

### HTTP 测试失败
检查服务日志：
```bash
docker logs <container-name>
```

### 超时问题
增加等待时间或使用 `wait-healthy.sh`：
```bash
./tests/lib/wait-healthy.sh --timeout 180
```

## 许可证

MIT License
