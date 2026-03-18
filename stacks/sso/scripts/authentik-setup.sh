#!/usr/bin/env bash

# Authentik OIDC Provider 自动配置脚本
#
# 功能: 为 homelab 栈中的所有服务自动创建 OAuth2/OIDC Provider 和 Application
#
# 用法:
#   ./authentik-setup.sh [--dry-run] [--domain DOMAIN]
#
# 示例:
#   ./authentik-setup.sh --dry-run        # 预览将要创建的资源
#   ./authentik-setup.sh                 # 实际创建
#   ./authentik-setup.sh --domain example.com  # 指定域名
#
# 前置条件:
# - Authentik 已部署并运行 (stacks/sso)
# - .env 文件已配置 AUTHENTIK_BOOTSTRAP_TOKEN 或管理员账号密码
# - 可访问 Authentik API: http://localhost:9000

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS_DIR="${SCRIPT_DIR}/../.."
cd "${STACKS_DIR}/sso"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
AUTHENTIK_URL="${AUTHENTIK_URL:-http://localhost:9000}"
DRY_RUN=false
DOMAIN="${DOMAIN:-localhost}"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    -h|--help)
      echo "用法: $0 [--dry-run] [--domain DOMAIN]"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 加载 .env 文件
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
else
  echo -e "${YELLOW}⚠ 未找到 .env 文件，使用默认值${NC}"
fi

# 检查 AUTHENTIK_BOOTSTRAP_TOKEN
if [ -z "${AUTHENTIK_BOOTSTRAP_TOKEN:-}" ]; then
  echo -e "${RED}✗ AUTHENTIK_BOOTSTRAP_TOKEN 未设置${NC}"
  echo "请先在 .env 中设置，或通过环境变量导出"
  echo ""
  echo "获取 token 方法:"
  echo "1. 登录 Authentik Web UI (http://auth.${DOMAIN})"
  echo "2. 用户菜单 → API Tokens → Create Token"
  echo "3. 复制 token 到 AUTHENTIK_BOOTSTRAP_TOKEN"
  exit 1
fi

echo -e "${BLUE}=== Authentik OIDC 自动配置脚本 ===${NC}"
echo ""
echo "配置:"
echo "  URL: ${AUTHENTIK_URL}"
echo "  DOMAIN: ${DOMAIN}"
echo "  DRY_RUN: ${DRY_RUN}"
echo ""

# 服务定义列表
# 格式: 服务名:应用名:回调URL
SERVICES=(
  "Grafana:Grafana:https://grafana.${DOMAIN}/login/generic_oauth"
  "Gitea:Gitea:https://gitea.${DOMAIN}/user/oauth/authentik/callback"
  "Nextcloud:Nextcloud:https://nextcloud.${DOMAIN}/apps/oauth2/external/authentik/redirect"
  "Outline:Outline:https://outline.${DOMAIN}/auth/oauth2/callback"
  "OpenWebUI:OpenWebUI:https://openwebui.${DOMAIN}/api/auth/oauth2/callback"
  "Portainer:Portainer:https://portainer.${DOMAIN}/oauth/callback"
)

# 测试连接
echo "测试 Authentik API 连接..."
if curl -s -f -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" "${AUTHENTIK_URL}/api/v3/application/adapters/oauth2" > /dev/null; then
  echo -e "${GREEN}✓ API 连接正常${NC}"
else
  echo -e "${RED}✗ 无法连接 Authentik API${NC}"
  echo "请检查:"
  echo "1. Authentik 是否运行: docker compose -f stacks/sso/docker-compose.yml ps"
  echo "2. URL 是否正确: AUTHENTIK_URL=${AUTHENTIK_URL}"
  echo "3. Token 是否有效"
  exit 1
fi

echo ""
echo -e "${BLUE}开始配置 OIDC Providers...${NC}"
echo ""

# 函数: 创建 OAuth2 Provider
create_provider() {
  local name="$1"
  local client_id="$2"
  local client_secret="$3"
  local redirect_uri="$4"

  echo -e "  ${YELLOW}▶${NC} Provider: ${name}"
  echo "    客户端 ID: ${client_id}"
  echo "    回调 URL: ${redirect_uri}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "    ${YELLOW}[DRY-RUN] 跳过创建${NC}"
    return 0
  fi

  # 创建 OAuth2 Provider
  local provider_data
  provider_data=$(cat <<EOF
{
  "name": "${name}",
  "authenticationFlow": "default-provider-auth",
  "authorizationFlow": "default-provider-auth",
  "clientId": "${client_id}",
  "clientSecret": "${client_secret}",
  "policyEngineMode": "any",
  "redirectUris": ["${redirect_uri}"],
  "subdomainBypass": false,
  "tokenDuration": 3600,
  "issuerMode": "static",
  "mode": "managed"
}
EOF
)

  response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/application/adapters/oauth2/" \
    -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${provider_data}")

  if echo "${response}" | grep -q '"pk"'; then
    local pk=$(echo "${response}" | grep -o '"pk":"[^"]*"' | cut -d'"' -f4)
    echo -e "    ${GREEN}✓ 创建成功 (PK: ${pk:0:8}...)${NC}"
    return 0
  else
    echo -e "    ${RED}✗ 创建失败${NC}"
    echo "    响应: ${response}"
    return 1
  fi
}

# 函数: 创建 Application
create_application() {
  local name="$1"
  local provider_pk="$2"
  local group_name="$3"

  echo -e "  ${YELLOW}▶${NC} Application: ${name}"
  echo "    关联 Provider PK: ${provider_pk:0:8}..."
  echo "    用户组: ${group_name}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "    ${YELLOW}[DRY-RUN] 跳过创建${NC}"
    return 0
  fi

  # 先查找或创建组
  group_pk=""
  if [ -n "${group_name}" ]; then
    group_response=$(curl -s -X GET "${AUTHENTIK_URL}/api/v3/group/?search=${group_name}" \
      -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}")
    group_pk=$(echo "${group_response}" | grep -o '"pk":"[^"]*"' | head -1 | cut -d'"' -f4 || true)

    if [ -z "${group_pk}" ]; then
      # 创建组
      group_create_data=$(cat <<EOF
{
  "name": "${group_name}",
  "isSuperUser": false,
  "isSystem": false
}
EOF
)
      group_create_response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/group/" \
        -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${group_create_data}")
      group_pk=$(echo "${group_create_response}" | grep -o '"pk":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
      if [ -n "${group_pk}" ]; then
        echo -e "    ${GREEN}✓ 创建用户组: ${group_name}${NC}"
      fi
    else
      echo -e "    ${GREEN}✓ 使用现有用户组: ${group_name}${NC}"
    fi
  fi

  # 创建 Application
  local app_data
  app_data=$(cat <<EOF
{
  "name": "${name}",
  "provider": "${provider_pk}",
  "metaData": {},
  "policyBindingMode": "required",
  "group": $(if [ -n "${group_pk}" ]; then echo "\"${group_pk}\""; else echo "null"; fi)
}
EOF
)

  local response
  response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/application/" \
    -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${app_data}")

  if echo "${response}" | grep -q '"pk"'; then
    local app_pk=$(echo "${response}" | grep -o '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "    ${GREEN}✓ Application 创建成功 (PK: ${app_pk:0:8}...)${NC}"
    return 0
  else
    echo -e "    ${RED}✗ Application 创建失败${NC}"
    echo "    响应: ${response}"
    return 1
  fi
}

# 主流程
success_count=0
fail_count=0
results=()

for service in "${SERVICES[@]}"; do
  IFS=':' read -r name app_name redirect_uri <<< "${service}"

  echo -e "${BLUE}▶ ${name}${NC}"

  # 生成随机 client ID 和 secret
  client_id=$(openssl rand -hex 16 2>/dev/null || echo "auto-generated")
  client_secret=$(openssl rand -base64 32 2>/dev/null || echo "auto-generated")

  # 创建 Provider
  if create_provider "${name}" "${client_id}" "${client_secret}" "${redirect_uri}"; then
    # 获取刚创建的 provider PK (简化: 通过列表搜索)
    provider_pk=$(curl -s -X GET "${AUTHENTIK_URL}/api/v3/application/adapters/oauth2/?search=${name}" \
      -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" | grep -o '"pk":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "${provider_pk}" ]; then
      # 确定用户组
      group_name=""
      case "${name}" in
        "Jellyfin"|"Jellyseerr") group_name="media-users" ;;
        "Grafana"|"Gitea"|"Nextcloud"|"Outline"|"OpenWebUI") group_name="homelab-users" ;;
        "Portainer") group_name="homelab-admins" ;;
      esac

      # 创建 Application
      if create_application "${app_name}" "${provider_pk}" "${group_name}"; then
        success_count=$((success_count + 1))
        results+=("${GREEN}✓${NC} ${name}")
      else
        fail_count=$((fail_count + 1))
        results+=("${RED}✗${NC} ${name} (Application 创建失败)")
      fi
    else
      fail_count=$((fail_count + 1))
      results+=("${RED}✗${NC} ${name} (Provider PK 未找到)")
    fi
  else
    fail_count=$((fail_count + 1))
    results+=("${RED}✗${NC} ${name} (Provider 创建失败)")
  fi

  echo ""
done

# 输出汇总
echo ""
echo "================================"
echo -e "${BLUE}配置完成${NC}"
echo ""
echo -e "成功: ${GREEN}${success_count}${NC}"
echo -e "失败: ${RED}${fail_count}${NC}"
echo ""

if [ ${success_count} -gt 0 ]; then
  echo "各服务 OIDC 配置凭据:"
  echo ""
  echo "注意: 以下凭据已自动创建，请在各服务配置中使用:"
  echo ""
  for result in "${results[@]}"; do
    if [[ "${result}" == *"✓"* ]]; then
      echo "  ${result}"
    fi
  done
  echo ""
  echo "详细凭据请查看 Authentik Web UI → Applications"
fi

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo -e "${YELLOW}这是模拟运行 (--dry-run)。${NC}"
  echo -e "${YELLOW}要实际创建，请去掉 --dry-run 参数重新运行。${NC}"
fi

exit $((fail_count > 0 ? 1 : 0))