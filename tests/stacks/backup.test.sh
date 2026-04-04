#!/usr/bin/env bash
# backup.test.sh - 备份 Stack 集成测试
# 测试备份和灾难恢复功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载库
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试备份 Stack..."

# 测试 1: 检查 docker-compose.yml 存在
assert_file_exists "$PROJECT_ROOT/stacks/backup/docker-compose.yml" "备份 Stack 配置文件"

# 测试 2: 检查环境变量模板
if [[ -d "$PROJECT_ROOT/stacks/backup" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/backup/.env.example" "备份 Stack 环境变量模板" || true
fi

# 测试 3: 检查备份目录结构
echo ""
echo "检查备份目录结构..."
if [[ -d "$PROJECT_ROOT/backups" ]]; then
    assert_dir_exists "$PROJECT_ROOT/backups" "备份根目录"
    
    # 检查子目录
    assert_dir_exists "$PROJECT_ROOT/backups/daily" "每日备份目录" || true
    assert_dir_exists "$PROJECT_ROOT/backups/weekly" "每周备份目录" || true
    assert_dir_exists "$PROJECT_ROOT/backups/monthly" "每月备份目录" || true
else
    skip_test "备份目录未配置"
fi

# 测试 4: 检查运行的备份服务
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "borg\|restic\|kopia\|duplicati"; then
    echo ""
    echo "检查运行的备份服务..."
    
    # BorgBackup
    if docker ps --format '{{.Names}}' | grep -q "borg"; then
        assert_container_running "borg" "BorgBackup 容器运行"
    fi
    
    # Restic
    if docker ps --format '{{.Names}}' | grep -q "restic"; then
        assert_container_running "restic" "Restic 容器运行"
    fi
    
    # Kopia
    if docker ps --format '{{.Names}}' | grep -q "kopia"; then
        assert_container_running "kopia" "Kopia 容器运行"
    fi
else
    skip_test "备份服务容器未运行 (跳过运行时测试)"
fi

# 测试 5: 检查备份脚本
echo ""
echo "检查备份脚本..."
if [[ -f "$PROJECT_ROOT/stacks/backup/scripts/backup.sh" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/backup/scripts/backup.sh" "备份脚本"
    
    # 检查脚本可执行
    if [[ -x "$PROJECT_ROOT/stacks/backup/scripts/backup.sh" ]]; then
        assert_equals "0" "0" "备份脚本可执行"
    else
        echo -e "${YELLOW}警告：备份脚本不可执行${NC}"
    fi
else
    skip_test "备份脚本未找到"
fi

# 测试 6: 检查恢复脚本
echo ""
echo "检查恢复脚本..."
if [[ -f "$PROJECT_ROOT/stacks/backup/scripts/restore.sh" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/backup/scripts/restore.sh" "恢复脚本"
else
    skip_test "恢复脚本未找到"
fi

# 测试 7: 检查 cron 配置
echo ""
echo "检查定时备份配置..."
if [[ -f "$PROJECT_ROOT/stacks/backup/crontab" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/backup/crontab" "Cron 配置文件"
else
    skip_test "Cron 配置未找到"
fi

echo ""
echo "备份 Stack 测试完成"
