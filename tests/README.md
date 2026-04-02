# HomeLab Stack - Integration Tests

完整的集成测试套件,用于验证所有服务的正常运行。

## 快速开始

```bash
# 测试特定栈
./tests/run-tests.sh --stack base

# 测试所有栈
./tests/run-tests.sh --all

# 生成JSON报告
./tests/run-tests.sh --all --json
```

## 目录结构

```
tests/
├── run-tests.sh              # 主测试运行器
├── lib/
│   ├── assert.sh             # 断言库
│   ├── docker.sh             # Docker工具函数
│   ├── report.sh             # 报告生成器
│   └── wait-healthy.sh       # 等待健康辅助脚本
├── stacks/
│   ├── base.test.sh          # Base栈测试
│   ├── monitoring.test.sh    # Monitoring栈测试
│   └── ...                   # 其他栈测试
├── e2e/
│   ├── sso-flow.test.sh      # SSO流程端到端测试
│   └── backup-restore.test.sh # 备份恢复端到端测试
├── ci/
│   └── docker-compose.test.yml # CI专用compose
└── results/
    ├── report.json           # JSON测试报告
    └── report.html           # HTML测试报告
```

## 可用的测试命令

### 基本命令

```bash
# 显示帮助
./tests/run-tests.sh --help

# 列出所有可用栈
./tests/run-tests.sh --list

# 测试单个栈
./tests/run-tests.sh --stack base

# 测试所有栈
./tests/run-tests.sh --all

# 生成JSON报告
./tests/run-tests.sh --all --json
```

### 断言库API

```bash
# 相等断言
assert_eq "actual" "expected" "描述"

# 非空断言
assert_not_empty "value" "描述"

# 退出码断言
assert_exit_code 0 "描述"

# 容器运行断言
assert_container_running "container_name"

# 容器健康断言
assert_container_healthy "container_name" 60

# HTTP 200断言
assert_http_200 "http://localhost:8080/health"

# HTTP响应断言
assert_http_response "http://localhost:8080/api" "expected_pattern"

# JSON值断言
assert_json_value "$json" ".key" "expected"

# JSON键存在断言
assert_json_key_exists "$json" ".key"

# 无错误断言
assert_no_errors "$json"

# 文件内容断言
assert_file_contains "/path/to/file" "pattern"

# 无latest镜像断言
assert_no_latest_images "stacks/base"
```

## 编写新测试

### 创建新的栈测试

1. 创建测试文件 `tests/stacks/<stack-name>.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

STACK_NAME="<stack-name>"

test_service_running() {
    assert_container_running "service-name" "Service should be running"
}

test_service_api() {
    assert_http_200 "http://localhost:8080/health" "API should be accessible"
}

run_tests() {
    echo "Testing $STACK_NAME stack..."
    test_service_running || true
    test_service_api || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
```

2. 让脚本可执行:
```bash
chmod +x tests/stacks/<stack-name>.test.sh
```

3. 运行测试:
```bash
./tests/run-tests.sh --stack <stack-name>
```

## 测试分类

### Level 1 - 容器健康测试 (必须)

- 验证容器运行状态
- 验证健康检查
- 验证compose文件语法

### Level 2 - HTTP端点测试 (必须)

- 验证Web UI可达性
- 验证API健康端点
- 验证基本响应

### Level 3 - 服务间互通测试 (必须)

- Prometheus抓取指标
- Grafana数据源连接
- 服务间网络通信

### Level 4 - E2E流程测试 (可选)

- SSO完整登录流程
- 备份恢复流程
- 端到端业务逻辑

## CI集成

测试会自动在GitHub Actions中运行:

- **触发条件**: 推送或PR修改了 `stacks/`, `scripts/`, `tests/` 目录
- **运行环境**: Ubuntu 22.04
- **测试范围**: Base栈
- **报告**: 自动上传到Artifacts

## 环境变量

测试可能需要以下环境变量:

```bash
export GRAFANA_ADMIN_PASSWORD="admin"
export SONARR_API_KEY="your-key"
export RADARR_API_KEY="your-key"
export NEXTCLOUD_ADMIN_PASSWORD="admin"
```

## 故障排查

### 测试失败

1. 检查容器状态:
```bash
docker ps -a
```

2. 查看容器日志:
```bash
docker logs <container-name>
```

3. 手动测试端点:
```bash
curl http://localhost:8080/health
```

### 容器不健康

1. 增加等待超时:
```bash
assert_container_healthy "container" 120  # 等待120秒
```

2. 检查健康检查配置:
```bash
docker inspect <container> | jq '.[0].Config.Healthcheck'
```

### 网络问题

1. 检查网络:
```bash
docker network ls
docker network inspect <network-name>
```

2. 测试容器间连接:
```bash
docker exec <container1> ping <container2>
```

## 最佳实践

1. **测试独立性**: 每个测试应该独立,不依赖其他测试
2. **清理资源**: 测试后清理创建的资源
3. **超时设置**: 为所有HTTP请求设置合理超时
4. **错误处理**: 使用 `|| true` 防止测试失败中断整个套件
5. **日志输出**: 提供清晰的测试输出和错误信息

## 贡献

添加新测试时,请确保:

1. 遵循现有测试结构
2. 添加完整的文档注释
3. 使用断言库函数
4. 测试通过shellcheck检查
5. 更新相关文档

## License

MIT
