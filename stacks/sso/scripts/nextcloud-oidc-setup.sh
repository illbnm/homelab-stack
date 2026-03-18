#!/usr/bin/env bash

# Nextcloud OIDC 集成配置脚本
#
# 用法:
#   ./nextcloud-oidc-setup.sh --domain DOMAIN --client-id CLIENT_ID --client-secret CLIENT_SECRET
#
# 示例:
#   ./nextcloud-oidc-setup.sh --domain auth.example.com --client-id abc123 --client-secret xyz789
#
# 前置条件:
# - Nextcloud 已安装并运行
# - Social login / OIDC 应用已启用 (apps → Social login / OIDC)
# - 可通过 occ 命令管理配置

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../.."

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 参数
DOMAIN=""
CLIENT_ID=""
CLIENT_SECRET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --client-secret)
      CLIENT_SECRET="$2"
      shift 2
      ;;
    -h|--help)
      echo "用法: $0 --domain DOMAIN --client-id CLIENT_ID --client-secret CLIENT_SECRET"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

if [ -z "${DOMAIN}" ] || [ -z "${CLIENT_ID}" ] || [ -z "${CLIENT_SECRET}" ]; then
  echo "缺少必需参数"
  echo "用法: $0 --domain DOMAIN --client-id CLIENT_ID --client-secret CLIENT_SECRET"
  exit 1
fi

echo -e "${BLUE}=== Nextcloud OIDC 配置脚本 ===${NC}"
echo ""
echo "配置:"
echo "  DOMAIN: ${DOMAIN}"
echo "  Client ID: ${CLIENT_ID}"
echo "  Client Secret: ${CLIENT_SECRET:0:8}..."
echo ""

# 检查 occ 命令
if ! docker compose -f stacks/productivity/docker-compose.yml exec -T nextcloud which occ &> /dev/null; then
  echo -e "${RED}✗ 无法找到 occ 命令${NC}"
  echo "请确认 Nextcloud 栈已部署并运行"
  exit 1
fi

echo "正在配置 Nextcloud OIDC..."

# 1. 启用 Social login 应用
echo -e "${YELLOW}▶ 检查 Social login 应用...${NC}"
if ! docker compose -f stacks/productivity/docker-compose.yml exec -T nextcloud occ app:list | grep -q "sociallogin"; then
  echo "  安装 Social login 应用..."
  docker compose -f stacks/productivity/docker-compose.yml exec -T nextcloud occ app:install sociallogin || {
    echo -e "${RED}✗ 安装失败${NC}"
    exit 1
  }
  echo -e "  ${GREEN}✓ 已安装${NC}"
else
  echo -e "  ${GREEN}✓ 已安装${NC}"
fi

# 2. 配置 OIDC
echo -e "${YELLOW}▶ 配置 OIDC 提供商...${NC}"

config_args=(
  "oidc_loginEnabled=true"
  "oidc_login_providerName=Authentik"
  "oidc_login_client_id=${CLIENT_ID}"
  "oidc_login_client_secret=${CLIENT_SECRET}"
  "oidc_login_authorization_endpoint=https://auth.${DOMAIN}/application/o/authorize/"
  "oidc_login_token_endpoint=https://auth.${DOMAIN}/application/o/token/"
  "oidc_login_userinfo_endpoint=https://auth.${DOMAIN}/application/v1/users/@me"
  "oidc_login_scope=openid email profile"
  "oidc_login_button_text=Authentik"
  "oidc_login_use_relay_state=false"
  "oidc_login_auto_redirect=false"
  "oidc_login_want_claims_discovery=true"
  "oidc_login_use_id_token=true"
  "oidc_login_use_userinfo=true"
)

for arg in "${config_args[@]}"; do
  IFS='=' read -r key value <<< "${arg}"
  echo "  设置: ${key}"
  docker compose -f stacks/productivity/docker-compose.yml exec -T nextcloud occ config:app:set --value "${value}" sociallogin --key "${key}" 2>/dev/null || true
done

# 3. 验证配置
echo ""
echo -e "${YELLOW}▶ 验证配置...${NC}"
echo "当前 OIDC 配置:"
docker compose -f stacks/productivity/docker-compose.yml exec -T nextcloud occ config:app:get sociallogin 2>/dev/null || echo "  (无配置)"

echo ""
echo -e "${GREEN}✓ Nextcloud OIDC 配置完成!${NC}"
echo ""
echo "下一步:"
echo "1. 访问 Nextcloud Web UI"
echo "2. 登录 → 用户菜单 → Apps → Social login → Enable OIDC login"
echo "3. 在登录页面会出现 'Authentik' 按钮"
echo "4. 点击后跳转到 Authentik 登录，成功后返回 Nextcloud"
echo ""
echo "测试用户:"
echo "  - 在 Authentik 中创建用户并分配到 homelab-users 组"
echo "  - 使用该用户登录 Nextcloud via OIDC"