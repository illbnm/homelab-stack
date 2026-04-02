# 贡献指南

感谢你对 HomeLab Stack 项目的兴趣! 🎉

## 🚀 快速开始

### 1. Fork & Clone

```bash
# Fork 后克隆你的仓库
git clone https://github.com/YOUR_USERNAME/homelab-stack.git
cd homelab-stack

# 添加上游仓库
git remote add upstream https://github.com/illbnm/homelab-stack.git
```

### 2. 开发环境设置

```bash
# 运行安装脚本
./install.sh

# 复制环境变量
cp .env.example .env

# 生成密钥
./scripts/generate-secrets.sh
```

### 3. 创建功能分支

```bash
# 创建新分支
git checkout -b feature/my-new-feature

# 或修复bug
git checkout -b fix/my-bug-fix
```

## 📝 代码规范

### Bash 脚本

- 使用 `#!/usr/bin/env bash` 作为shebang
- 启用严格模式: `set -euo pipefail`
- 使用 [[ ]] 代替 [ ] 进行条件测试
- 使用变量时加引号: "$variable"
- 通过 [ShellCheck](https://www.shellcheck.net/) 检查脚本

示例:
```bash
#!/usr/bin/env bash
set -euo pipefail

# 好的实践
if [[ -f "$file" ]]; then
    echo "File exists: $file"
fi

# 避免
if [ -f $file ]; then
    echo "File exists"
fi
```

### Docker Compose

- 所有镜像使用明确版本标签,避免 `:latest`
- 为每个服务添加 `healthcheck`
- 使用 `.env` 文件管理配置
- 遵循 [Docker Compose 最佳实践](https://docs.docker.com/compose/best-practices/)

示例:
```yaml
services:
  app:
    image: nginx:1.25.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    environment:
      - DOMAIN=${DOMAIN}
    volumes:
      - ./config:/config:ro
```

### 文档

- 使用 Markdown 格式
- 为复杂配置添加注释
- 更新相关文档和README

## 🧪 测试

### 运行测试

```bash
# 测试特定栈
./tests/run-tests.sh --stack base

# 测试所有栈
./tests/run-tests.sh --all

# 生成JSON报告
./tests/run-tests.sh --all --json
```

### 添加新测试

每个新 Stack PR **必须** 包含对应的测试文件:

1. 创建 `tests/stacks/<stack-name>.test.sh`
2. 实现测试函数
3. 确保通过 `shellcheck` 检查
4. 更新文档

示例测试:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"

STACK_NAME="my-stack"

test_service_running() {
    assert_container_running "service-name" "Service should be running"
}

run_tests() {
    test_service_running || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
```

## 📦 Pull Request 流程

### 1. 提交前检查

```bash
# 运行 ShellCheck
shellcheck scripts/*.sh tests/**/*.sh

# 运行测试
./tests/run-tests.sh --all

# 检查 compose 语法
find stacks -name "docker-compose.yml" -exec docker compose -f {} config --quiet \;
```

### 2. 提交代码

```bash
# 添加修改的文件
git add .

# 提交(使用语义化提交信息)
git commit -m "feat: add new monitoring stack"
# 或
git commit -m "fix: resolve traefik configuration issue"
# 或
git commit -m "docs: update README with new instructions"
```

提交信息格式:
- `feat:` 新功能
- `fix:` Bug修复
- `docs:` 文档更新
- `test:` 测试相关
- `chore:` 构建/工具相关
- `refactor:` 代码重构

### 3. 推送 & 创建PR

```bash
# 推送到你的fork
git push origin feature/my-new-feature

# 在GitHub上创建Pull Request
```

### 4. PR 标题和描述

标题格式: `[Stack Name] Brief description`

示例:
```
[Monitoring] Add Prometheus alerting rules

- Add alert rules for CPU, memory, and disk usage
- Configure Alertmanager with Slack integration
- Add tests for alerting endpoints

Closes #123
```

## ✅ 验收标准

PR 必须满足:

- [ ] 代码通过 ShellCheck 检查
- [ ] 所有测试通过
- [ ] 包含必要的文档更新
- [ ] 遵循代码规范
- [ ] 没有合并冲突
- [ ] 添加测试覆盖(如果是新功能)

## 💰 Bounty 任务

我们为特定任务提供赏金! 查看 [BOUNTY.md](BOUNTY.md) 了解可用任务。

### 认领 Bounty

1. 在Issue中评论 "我来认领"
2. 说明你的实现思路
3. 创建PR并关联Issue
4. 通过验收后获得赏金

## 🤝 获取帮助

- 查看现有 [Issues](https://github.com/illbnm/homelab-stack/issues)
- 阅读 [文档](docs/)
- 提出新 [Issue](https://github.com/illbnm/homelab-stack/issues/new)

## 📋 开发提示

### 常用命令

```bash
# 查看日志
docker compose -f stacks/base/docker-compose.yml logs -f

# 重启服务
docker compose -f stacks/base/docker-compose.yml restart

# 清理资源
docker compose -f stacks/base/docker-compose.yml down -v

# 检查配置
docker compose -f stacks/base/docker-compose.yml config
```

### 调试技巧

1. **查看容器状态**
```bash
docker ps -a
docker inspect <container-name>
```

2. **查看日志**
```bash
docker logs <container-name>
docker logs -f <container-name>  # 实时查看
```

3. **进入容器**
```bash
docker exec -it <container-name> /bin/bash
```

4. **网络调试**
```bash
docker network ls
docker network inspect <network-name>
```

## 🙏 致谢

感谢所有贡献者的付出!

---

**Happy Coding! 🎉**
