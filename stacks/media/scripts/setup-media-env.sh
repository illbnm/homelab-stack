#!/usr/bin/env bash

# Media Stack 环境配置验证脚本
# 检查 docker-compose 启动前的所有依赖和配置

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS_DIR="${SCRIPT_DIR}/.."
cd "${STACKS_DIR}"

echo "=== Media Stack 环境检查 ==="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    return 1
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. 检查 .env 文件
if [ ! -f ".env" ]; then
    check_fail "未找到 .env 文件，请复制 .env.example 并修改"
    echo "  执行: cp .env.example .env && vim .env"
    exit 1
else
    check_pass "找到 .env 文件"
fi

# 2. 验证必需变量
echo ""
echo "检查必需环境变量..."

source .env 2>/dev/null || true  # 加载但不失败

errors=0

check_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"

    if [ -z "$var_value" ]; then
        check_fail "  $var_name 未设置"
        errors=$((errors + 1))
    else
        check_pass "  $var_name = $var_value"
    fi
}

check_var "DOWNLOADS_ROOT"
check_var "MEDIA_ROOT"
check_var "PUID"
check_var "PGID"
check_var "DOMAIN"

if [ $errors -gt 0 ]; then
    echo ""
    echo "请编辑 .env 文件填写缺少的变量"
    exit 1
fi

# 3. 检查目录是否存在
echo ""
echo "检查存储目录..."

if [ ! -d "${DOWNLOADS_ROOT}" ]; then
    check_warn "  DOWNLOADS_ROOT 不存在 (将自动创建): ${DOWNLOADS_ROOT}"
    sudo mkdir -p "${DOWNLOADS_ROOT}" 2>/dev/null || {
        check_fail "  无法创建目录，请手动创建: sudo mkdir -p ${DOWNLOADS_ROOT}"
        exit 1
    }
    sudo chown -R "${PUID}:${PGID}" "${DOWNLOADS_ROOT}" 2>/dev/null || true
else
    check_pass "  DOWNLOADS_ROOT 存在: ${DOWNLOADS_ROOT}"
fi

if [ ! -d "${MEDIA_ROOT}" ]; then
    check_warn "  MEDIA_ROOT 不存在 (将自动创建): ${MEDIA_ROOT}"
    sudo mkdir -p "${MEDIA_ROOT}" 2>/dev/null || {
        check_fail "  无法创建目录，请手动创建: sudo mkdir -p ${MEDIA_ROOT}"
        exit 1
    }
    sudo chown -R "${PUID}:${PGID}" "${MEDIA_ROOT}" 2>/dev/null || true
else
    check_pass "  MEDIA_ROOT 存在: ${MEDIA_ROOT}"
fi

# 4. 检查子目录结构
echo ""
echo "检查目录结构..."

for subdir in "torrents/movies" "torrents/tv" "media/movies" "media/tv"; do
    full_path="${DOWNLOADS_ROOT}/../${subdir}"
    if [ -d "$full_path" ]; then
        check_pass "  $subdir 存在"
    else
        check_warn "  $subdir 不存在 (建议创建: mkdir -p $full_path)"
    fi
done

# 5. 检查 Docker 和 Docker Compose
echo ""
echo "检查 Docker 环境..."

if ! command -v docker &> /dev/null; then
    check_fail "  Docker 未安装"
    exit 1
else
    check_pass "  Docker 已安装 ($(docker --version | head -1))"
fi

if ! docker compose version &> /dev/null; then
    check_fail "  Docker Compose v2 未安装"
    exit 1
else
    check_pass "  Docker Compose 已安装 ($(docker compose version --short))"
fi

# 6. 检查 Docker 网络
echo ""
echo "检查 Docker 网络..."

if ! docker network ls | grep -q "proxy"; then
    check_fail "  proxy 网络不存在 (请先部署 Base Stack)"
    exit 1
else
    check_pass "  proxy 网络存在"
fi

if ! docker network ls | grep -q "internal"; then
    check_fail "  internal 网络不存在 (请先部署 Base Stack)"
    exit 1
else
    check_pass "  internal 网络存在"
fi

# 7. 检查文件权限
echo ""
echo "检查文件权限..."

if [ "$(id -u)" != "$PUID" ]; then
    check_warn "  当前用户 UID($(id -u)) 与 PUID(${PUID}) 不匹配"
    echo "  建议: 运行所有命令的用户 UID 等于 PUID，否则可能出现权限问题"
fi

# 8. 总结
echo ""
echo "================================"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ 所有检查通过，可以启动服务${NC}"
    echo ""
    echo "下一步:"
    echo "  docker compose up -d"
    echo ""
    exit 0
else
    echo -e "${RED}❌ 发现 $errors 个错误，请修复后重试${NC}"
    exit 1
fi