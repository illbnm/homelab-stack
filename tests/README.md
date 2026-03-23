# Homelab Integration Test Framework

集成测试框架用于验证 Homelab 各 Stack 的功能和连通性。

## 📁 目录结构

```
tests/
├── run-tests.sh          # 主测试运行器
├── README.md             # 本文档
├── lib/                  # 测试库
│   ├── assert.sh         # 断言函数库
│   └── docker.sh         # Docker 操作库
├── stacks/               # Stack 测试
│   ├── network.test.sh   # 网络 Stack 测试
│   ├── database.test.sh  # 数据库 Stack 测试
│   ├── observability.test.sh
│   ├── sso.test.sh       # SSO Stack 测试
│   ├── notifications.test.sh
│   └── backup.test.sh    # 备份 Stack 测试
└── reports/              # 测试报告
    └── junit.xml         # JUnit 格式报告
```

## 🚀 快速开始

### 前置条件

- Docker 和 docker-compose 已安装
- Bash 4.0+
- 可选：curl, nc, redis-cli, psql 等工具

### 运行所有测试

```bash
# 进入测试目录
cd tests/

# 运行所有测试
./run-tests.sh
```

### 运行单个 Stack 测试

```bash
# 运行网络测试
bash stacks/network.test.sh

# 运行数据库测试
bash stacks/database.test.sh
```

## 📊 输出格式

### 控制台输出

```
╔═══════════════════════════════════════════════════════════╗
║         Homelab Integration Test Framework                ║
╚═══════════════════════════════════════════════════════════╝

检查环境...
✓ Docker 可用
✓ docker-compose 可用
找到 6 个测试文件

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  测试：network
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
测试网络 Stack...
✓ 网络 Stack 配置文件：/path/to/stacks/network/docker-compose.yml
✓ DNS 解析正常
✓ 外网连接正常

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  测试摘要
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  总计：  6
  通过：  5
  失败：  1
  跳过：  0
  耗时：  45s

  ✗ 有测试失败
```

### JUnit XML 报告

测试完成后生成 `reports/junit.xml`，可导入 CI/CD 系统。

## 🔧 断言函数

### 基础断言

```bash
# 值相等
assert_equals "expected" "actual" "描述"

# 值非空
assert_not_empty "$value" "描述"

# 文件存在
assert_file_exists "/path/to/file" "描述"

# 目录存在
assert_dir_exists "/path/to/dir" "描述"
```

### Docker 断言

```bash
# 容器运行中
assert_container_running "container_name" "描述"

# 端口监听
assert_port_listening "8080" "描述"

# HTTP 状态码
assert_http_status "200" "http://localhost:8080" "描述"
```

### 工具函数

```bash
# 等待容器就绪
wait_for_container "container_name" 30 2

# 等待端口就绪
wait_for_port "8080" "localhost" 30 2

# 跳过测试
skip_test "原因说明"
```

## 📝 编写新测试

1. 在 `stacks/` 目录创建 `<stack-name>.test.sh`
2. 加载库文件
3. 使用断言函数编写测试
4. 运行测试验证

### 示例

```bash
#!/usr/bin/env bash
# mystack.test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试 MyStack..."

# 测试配置文件存在
assert_file_exists "$PROJECT_ROOT/stacks/mystack/docker-compose.yml" "配置文件"

# 测试容器运行
assert_container_running "mystack" "容器运行"

# 测试端口
wait_for_port "9999" "localhost" 10
assert_http_status "200" "http://localhost:9999" "Web UI"

echo "MyStack 测试完成"
```

## 🎯 测试策略

### 分层测试

1. **配置层**: 检查 docker-compose.yml, .env.example 存在
2. **运行时层**: 检查容器运行状态、端口监听
3. **功能层**: HTTP 请求、API 调用、数据库查询
4. **集成层**: Stack 间依赖、网络连通性

### 跳过策略

使用 `skip_test` 跳过不适用的测试：

- 容器未运行时跳过运行时测试
- 缺少工具时跳过相关测试
- 需要凭据时跳过认证测试

### 超时设置

```bash
# 默认超时
wait_for_port "8080" "localhost" 30  # 30 秒

# 快速检查
wait_for_port "8080" "localhost" 5   # 5 秒

# 慢速服务
wait_for_container "db" 60 5         # 60 秒，每 5 秒检查
```

## 🔍 调试技巧

### 查看详细日志

```bash
# 运行测试并保存输出
./run-tests.sh 2>&1 | tee test-output.log

# 查看容器日志
docker logs <container_name> --tail 100
```

### 手动测试

```bash
# 测试 HTTP 端点
curl -v http://localhost:8080

# 测试端口
nc -zv localhost 8080

# 检查容器
docker ps -a
docker inspect <container>
```

## 📈 CI/CD 集成

### GitHub Actions

```yaml
- name: Run Integration Tests
  run: |
    cd tests/
    ./run-tests.sh

- name: Upload Test Report
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: tests/reports/junit.xml
```

### Jenkins

```groovy
post {
    always {
        junit 'tests/reports/junit.xml'
    }
}
```

## ⚠️ 注意事项

1. **不要修改生产数据**: 测试应在隔离环境运行
2. **清理资源**: 测试后清理临时容器和网络
3. **并行测试**: 避免同时运行多个测试实例
4. **超时处理**: 设置合理的超时时间避免卡住

## 📚 相关文档

- [Homelab 主文档](../README.md)
- [各 Stack 文档](../stacks/*/README.md)
- [Docker 最佳实践](https://docs.docker.com/)
