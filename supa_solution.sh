 Make sure to include the correct license and any necessary setup instructions.
```

## 解决方案

```bash
# run-tests.sh
#!/bin/bash
# 1. Initialize the environment
if [ ! -d tests ]; then
    echo "Creating test directory..."
    mkdir -p tests
fi

# 2. Configure the stack name
stack_name="$1"

# 3. Start the service
echo "Starting $stack_name service..."
docker start $stack_name

# 4. Check the container status
echo "Checking container status..."
docker ps -f name=$stack_name --no-headers --format "{{.Status}}" | grep -v "up" | wc -l

# 5. Validate health checks
echo "Validating health checks..."
docker exec -it $stack_name health-checks

# 6. Test HTTP endpoints
echo "Testing HTTP endpoints..."
curl -v http://localhost:8081/api/data

# 7. Verify network connectivity
echo "Testing network connectivity..."
ping -c 4 127.0.0.1
```

## 说明

- 所有服务容器均以 `docker start` 命令启动
- 使用 `docker exec` 进入容器执行健康检查
- 使用 `curl` 测试 HTTP 端点
- 使用 `ping` 测试网络连接

## 简要说明

该套件