# ============================================================
# Home Automation Stack - Makefile
# ============================================================

.PHONY: help up down restart logs clean setup update

# 默认目标
.DEFAULT_GOAL := help

# 帮助信息
help:
	@echo "🏠 Home Automation Stack - 命令列表"
	@echo ""
	@echo "  make setup      - 初始化配置（首次运行）"
	@echo "  make up         - 启动所有服务"
	@echo "  make down       - 停止所有服务"
	@echo "  make restart    - 重启所有服务"
	@echo "  make logs       - 查看所有日志"
	@echo "  make logs-ha    - 查看 Home Assistant 日志"
	@echo "  make logs-nodered - 查看 Node-RED 日志"
	@echo "  make logs-mqtt  - 查看 Mosquitto 日志"
	@echo "  make clean      - 清理所有容器和卷"
	@echo "  make update     - 更新所有服务到最新版本"
	@echo "  make backup     - 备份配置"
	@echo ""

# 初始化设置
setup:
	@echo "🔧 初始化配置..."
	@./setup.sh

# 启动服务
up:
	@echo "🚀 启动服务..."
	@docker-compose up -d
	@echo "✓ 服务已启动"
	@make status

# 停止服务
down:
	@echo "🛑 停止服务..."
	@docker-compose down
	@echo "✓ 服务已停止"

# 重启服务
restart:
	@echo "🔄 重启服务..."
	@docker-compose restart
	@echo "✓ 服务已重启"

# 查看所有日志
logs:
	@docker-compose logs -f

# 查看 Home Assistant 日志
logs-ha:
	@docker-compose logs -f homeassistant

# 查看 Node-RED 日志
logs-nodered:
	@docker-compose logs -f nodered

# 查看 Mosquitto 日志
logs-mqtt:
	@docker-compose logs -f mosquitto

# 清理
clean:
	@echo "🧹 清理所有容器和卷..."
	@docker-compose down -v --remove-orphans
	@echo "✓ 清理完成"

# 更新
update:
	@echo "📥 拉取最新镜像..."
	@docker-compose pull
	@echo "✓ 镜像已更新"
	@make restart

# 备份
backup:
	@echo "💾 备份配置..."
	@mkdir -p backups
	@tar -czf backups/backup-$$(date +%Y%m%d-%H%M%S).tar.gz config/
	@echo "✓ 备份完成: backups/backup-$$(date +%Y%m%d-%H%M%S).tar.gz"

# 状态
status:
	@echo "📊 服务状态:"
	@docker-compose ps
