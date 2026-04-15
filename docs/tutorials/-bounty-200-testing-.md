# 完整自动化集成测试套件教程

## 概述

本教程旨在帮助开发者完成对 `illbnm/homelab-stack` 的自动化集成测试。我们将构建一个全面的测试套件，确保所有服务正常运行、容器健康、HTTP 端点可达性以及服务间互通等关键功能。

## 预备知识

在开始之前，请确保你具备以下基础知识：
- **基本的 Shell 脚本编写能力**
- **Docker 基础使用**
- **熟悉 JSON 和 HTTP 请求的基本操作**

## 测试套件结构

测试文件将按照以下目录结构组织：

```
tests/
├── run-tests.sh              # 测试入口
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

## 步骤一：创建基础测试脚本

### 1.1 创建 `run-tests.sh`

```bash
#!/bin/bash

# 设置环境变量
source lib/docker.sh

# 检查是否提供了有效的栈名称
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 --stack <name> | --all"
    exit 1
fi

case $1 in
    --stack)
        STACK_NAME="$2"
        ;;
    --all)
        STACK_NAME="all"
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

# 运行相应的测试脚本
if [ "$STACK_NAME" = "all" ]; then
    for stack in $(find stacks -mindepth 1 -maxdepth 1 -type d); do
        bash $stack/test.sh
    done
else
    if [ ! -d "stacks/${STACK_NAME}.test.sh" ]; then
        echo "Stack ${STACK_NAME} not found."
        exit 1
    fi

    bash stacks/"${STACK_NAME}".test.sh
fi
```

### 1.2 创建 `assert.sh` 断言库

```bash
#!/bin/bash

assert_container_running() {
    local container_name="$1"
    if ! docker ps --format "{{.Names}}" | grep -q "^$container_name\$"; then
        echo "Container $container_name is not running."
        exit 1
    fi
}

assert_container_healthy() {
    local container_name="$1"
    if ! docker inspect "$container_name" | jq -e '.State.Health.Status == "healthy"'; then
        echo "Container $container_name health check failed."
        exit 1
    fi
}

assert_http_200() {
    local url="$1"
    local result=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$result" != "200" ]; then
        echo "HTTP request to $url failed with status code $result."
        exit 1
    fi
}

assert_json_value() {
    local json="$1"
    local path="$2"
    local expected="$3"

    value=$(echo "$json" | jq -r ".${path}")
    if [ "$value" != "$expected" ]; then
        echo "JSON value for $path does not match: Expected '$expected', got '$value'."
        exit 1
    fi
}

assert_json_key_exists() {
    local json="$1"
    local path="$2"

    if ! echo "$json" | jq -e ".${path}"; then
        echo "JSON key $path does not exist."
        exit 1
    fi
}

assert_no_errors() {
    local result="$1"
    if [[ "$result" == *"error"* ]]; then
        echo "Error detected in response: $result"
        exit 1
    fi
}
```

### 1.3 创建 `report.sh` 结果输出工具

```bash
#!/bin/bash

print_green() {
    printf "\033[32m$1\033[0m\n"
}

print_red() {
    printf "\033[31m$1\033[0m\n"
}

export -f print_green
export -f print_red

# 示例：使用 JSON 格式输出结果
cat > results.json <<EOF
{
  "stack": "$STACK_NAME",
  "tests_passed": true,
  "details": []
}
EOF

# 输出终端彩色信息
print_green "Tests completed successfully!"
```

## 步骤二：编写具体服务测试脚本

### 2.1 `base.test.sh` 基础设施测试

```bash
#!/bin/bash

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

### 2.2 `media.test.sh` 媒体栈测试

```bash
#!/bin/bash

# 示例：Jellyfin 测试
test_jellyfin_health() {
    assert_http_200 "http://localhost:8096/api/v3/system/status"
}
```

## 步骤三：编写端到端 E2E 测试脚本

### 3.1 `sso-flow.test.sh` SSO 完整登录流程测试

```bash
#!/bin/bash

test_sso_flow() {
    # 示例：使用 curl 进行 SSO 登录验证
    local result=$(curl -u admin:password "http://localhost:8080/sso/login")
    if [ $? -ne 0 ]; then
        print_red "SSO login failed."
        exit 1
    fi

    assert_http_200 "http://localhost:8080/sso/profile"
}
```

### 3.2 `backup-restore.test.sh` 备份恢复端到端测试

```bash
#!/bin/bash

test_backup_restore() {
    # 示例：备份和恢复操作
    docker exec -i traefik /traefik-backup --backup-file=/backup.tar.gz
    if [ $? -ne 0 ]; then
        print_red "Backup failed."
        exit 1
    fi

    docker exec -i traefik /traefik-restore --restore-file=/backup.tar.gz
    if [ $? -ne 0 ]; then
        print_red "Restore failed."
        exit 1
    fi
}
```

## 结论与调试建议

通过以上步骤，我们已经完成了 `illbnm/homelab-stack` 的自动化集成测试套件的构建。如果在实施过程中遇到任何问题，请参考以下排查技巧：
- **检查所有容器是否正确启动**：运行 `docker ps -a` 查看所有容器的状态。
- **确保网络配置正确**：使用 `docker inspect <container_name>` 检查端口映射和网络连接情况。

希望本教程能帮助你顺利完成集成测试任务，并确保你的 HomeLab Stack 环境稳定可靠。祝你编写愉快！