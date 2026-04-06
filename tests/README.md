# HomeLab Stack Integration Tests

自动化集成测试套件，用于验证 HomeLab Stack 的所有服务是否正常运行。

## 快速开始

### 前置条件

- Bash 4.0+
- Docker 20.10+
- Docker Compose 2.0+
- curl, jq

### 运行测试

```bash
# 克隆仓库
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# 复制环境变量
cp .env.example .env

# 运行单个 stack 测试
./tests/run-tests.sh --stack base

# 运行所有测试
./tests/run-tests.sh --all

# 运行测试并生成 JSON 报告
./tests/run-tests.sh --stack base --json
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `--stack <name>` | 运行指定 stack 测试 |
| `--all` | 运行所有可用测试 |
| `--json` | 生成 JSON 报告 |
| `--help` | 显示帮助信息 |

## 可用 Stacks

| Stack | 说明 | 关键服务 |
|-------|------|----------|
| base | 基础设施 | Traefik, Portainer, Watchtower |
| media | 媒体栈 | Jellyfin, Sonarr, Radarr, qBittorrent |
| storage | 存储栈 | Nextcloud, Samba, Syncthing |
| monitoring | 监控栈 | Prometheus, Grafana, Loki |
| network | 网络栈 | AdGuard, Pi-hole, WireGuard |
| productivity | 生产力工具 | Gitea, n8n, Paperless |
| ai | AI 栈 | Ollama, Open WebUI |
| sso | SSO | Authentik |
| databases | 数据库 | PostgreSQL, MySQL, Redis, MongoDB |
| notifications | 通知服务 | Gotify, ntfy, Apprise |

## 断言库 API

### 基础断言

```bash
assert_eq "actual" "expected" "message"
assert_not_empty "value" "message"
assert_exit_code 0 $?
```

### Docker 断言

```bash
assert_container_running "container_name"
assert_container_healthy "container_name" 60
```

### HTTP 断言

```bash
assert_http_200 "http://localhost:8080" 30
assert_http_response "http://localhost:8080" "pattern"
```

### JSON 断言

```bash
assert_json_value "$json" ".key" "expected"
assert_json_key_exists "$json" ".data.items"
assert_no_errors "$json"
```

### 文件断言

```bash
assert_file_exists "/path/to/file"
assert_file_contains "/path/to/file" "pattern"
assert_compose_valid "/path/to/docker-compose.yml"
assert_no_latest_tags "/path/to/stacks"
```

## 新增 Stack 测试

1. 在 `tests/stacks/` 目录创建 `<stack>.test.sh`
2. 实现测试函数并调用断言
3. 在 `run-tests.sh` 的 `stacks` 数组中添加新 stack

## 故障排查

### 容器未运行

```bash
# 检查容器状态
docker ps -a

# 查看容器日志
docker logs <container_name>
```

### 测试超时

增加超时时间：
```bash
assert_container_healthy "container_name" 120
```

### HTTP 请求失败

检查服务端口是否正确映射：
```bash
docker port <container_name>
```

## CI 集成

### GitHub Actions

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: ./tests/run-tests.sh --all --json
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: tests/results/report.json
```

## 许可证

MIT License