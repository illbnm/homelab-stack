#!/bin/bash
# Authentik 初始化脚本
# 自动创建 OAuth2/OIDC Provider 和 Application
# 版权：MIT License | Copyright (c) 2026 思捷娅科技 (SJYKJ)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.${DOMAIN}}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"
DRY_RUN=false

# 打印使用信息
usage() {
    echo -e "${BLUE}用法：$0 [选项]${NC}"
    echo ""
    echo "选项:"
    echo "  --token, -t      Authentik API Token（必需，或使用 AUTHENTIK_TOKEN 环境变量）"
    echo "  --url, -u        Authentik URL（默认：https://auth.\${DOMAIN}）"
    echo "  --dry-run        预览模式，不实际创建"
    echo "  --help, -h       显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 --token your-api-token"
    echo "  $0 -t your-api-token --dry-run"
    exit 0
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --token|-t)
            AUTHENTIK_TOKEN="$2"
            shift 2
            ;;
        --url|-u)
            AUTHENTIK_URL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo -e "${RED}未知选项：$1${NC}"
            usage
            ;;
    esac
done

# 验证必需参数
if [ -z "$AUTHENTIK_TOKEN" ]; then
    echo -e "${RED}错误：缺少 API Token${NC}"
    echo ""
    echo "请通过以下方式获取 Token："
    echo "1. 访问 ${AUTHENTIK_URL}/if/admin/"
    echo "2. 进入 Admin → Users → 你的用户"
    echo "3. 点击 'Create Token' → 选择 'Service Token'"
    echo "4. 复制 Token 并传入 --token 参数"
    echo ""
    echo "或设置环境变量：export AUTHENTIK_TOKEN=your-token"
    exit 1
fi

# API 请求函数
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] ${method} ${endpoint}${NC}"
        return 0
    fi
    
    local response
    if [ "$method" = "GET" ]; then
        response=$(curl -sf \
            -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
            -H "Content-Type: application/json" \
            "${AUTHENTIK_URL}/api/v3/${endpoint}")
    elif [ "$method" = "POST" ]; then
        response=$(curl -sf \
            -X POST \
            -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${data}" \
            "${AUTHENTIK_URL}/api/v3/${endpoint}")
    fi
    
    echo "$response"
}

# 创建 Provider
create_provider() {
    local name=$1
    local redirect_uris=$2
    local signing_key="authentik"
    
    echo -e "${BLUE}创建 Provider: ${name}${NC}"
    
    local data=$(cat <<EOF
{
    "name": "${name}",
    "authorization_flow": "flow-default-provider-authorization",
    "authentication_flow": "flow-default-authentication-flow",
    "invalid_session_flow": "flow-default-invalid-session",
    "redirect_uris": "${redirect_uris}",
    "signing_key": "${signing_key}",
    "client_type": "confidential"
}
EOF
)
    
    local response
    response=$(api_request "POST" "providers/oauth2/" "$data")
    
    if [ $? -eq 0 ]; then
        local client_id=$(echo "$response" | jq -r '.client_id')
        local client_secret=$(echo "$response" | jq -r '.client_secret')
        echo -e "${GREEN}✓ Provider 创建成功${NC}"
        echo "  Client ID: ${client_id}"
        echo "  Client Secret: ${client_secret}"
        echo "  Redirect URI: ${redirect_uris}"
        echo ""
    else
        echo -e "${YELLOW}⚠ Provider 可能已存在，尝试获取...${NC}"
        # 尝试获取已存在的 provider
        local existing=$(api_request "GET" "providers/oauth2/?name=${name}")
        if [ -n "$existing" ]; then
            local client_id=$(echo "$existing" | jq -r '.results[0].client_id')
            echo -e "${GREEN}✓ 找到现有 Provider${NC}"
            echo "  Client ID: ${client_id}"
        fi
    fi
}

# 创建 Application
create_application() {
    local name=$1
    local slug=$2
    local provider_name=$3
    
    echo -e "${BLUE}创建 Application: ${name}${NC}"
    
    # 获取 provider UUID
    local provider_uuid
    provider_uuid=$(api_request "GET" "providers/oauth2/?name=${provider_name}" | jq -r '.results[0].pk')
    
    if [ -z "$provider_uuid" ] || [ "$provider_uuid" = "null" ]; then
        echo -e "${RED}✗ Provider 不存在：${provider_name}${NC}"
        return 1
    fi
    
    local data=$(cat <<EOF
{
    "name": "${name}",
    "slug": "${slug}",
    "provider": "${provider_uuid}",
    "backchannel_providers": []
}
EOF
)
    
    local response
    response=$(api_request "POST" "core/applications/" "$data")
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Application 创建成功${NC}"
        echo "  Slug: ${slug}"
        echo "  Open URL: ${AUTHENTIK_URL}/application/${slug}/"
        echo ""
    else
        echo -e "${YELLOW}⚠ Application 可能已存在${NC}"
    fi
}

# 主流程
main() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}       Authentik 初始化脚本${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    echo -e "Authentik URL: ${GREEN}${AUTHENTIK_URL}${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "模式：${YELLOW}DRY-RUN（预览）${NC}"
    fi
    echo ""
    
    # 验证连接
    echo -e "${BLUE}验证 Authentik 连接...${NC}"
    local version
    version=$(api_request "GET" "admin/config/" | jq -r '.version' 2>/dev/null)
    
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo -e "${RED}✗ 无法连接到 Authentik${NC}"
        echo "请检查："
        echo "  1. Authentik 是否正常运行"
        echo "  2. API Token 是否有效"
        echo "  3. URL 是否正确"
        exit 1
    fi
    
    echo -e "${GREEN}✓ 连接成功 (版本：${version})${NC}"
    echo ""
    
    # 定义服务列表
    declare -A services=(
        ["Grafana"]="https://grafana.${DOMAIN}/login/generic_oauth"
        ["Gitea"]="https://gitea.${DOMAIN}/user/oauth2/Authentik/callback"
        ["Nextcloud"]="https://nextcloud.${DOMAIN}/apps/sociallogin/custom-opener/oidc"
        ["Outline"]="https://outline.${DOMAIN}/auth/oidc.callback"
        ["Open WebUI"]="https://webui.${DOMAIN}/oidc/callback"
        ["Portainer"]="https://portainer.${DOMAIN}/"
        ["Node-RED"]="https://nodered.${DOMAIN}/"
        ["ESPHome"]="https://esphome.${DOMAIN}/"
    )
    
    # 创建 Provider 和 Application
    for service in "${!services[@]}"; do
        echo ""
        echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
        create_provider "$service" "${services[$service]}"
        create_application "$service" "${service,,}" "$service"
    done
    
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${GREEN}✓ 初始化完成！${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    echo "下一步："
    echo "1. 访问 ${AUTHENTIK_URL}/if/admin/"
    echo "2. 进入 Admin → Applications 查看所有应用"
    echo "3. 为每个服务配置对应的 OAuth2/OIDC 设置"
    echo "4. 参考各 stack 的 README.md 完成集成"
    echo ""
}

# 运行主函数
main
