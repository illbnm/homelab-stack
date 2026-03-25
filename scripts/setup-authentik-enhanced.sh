#!/bin/bash
#
# Authentik OIDC Provider 自动创建脚本
# 为所有 Homelab 服务创建 OAuth2/OIDC Provider 和 Application
#
# 用法:
#   ./scripts/authentik-setup.sh              # 正常执行
#   ./scripts/authentik-setup.sh --dry-run    # 预览模式
#

set -e

# ==================== 配置 ====================
AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.example.com}"
AUTHENTIK_API_URL="${AUTHENTIK_URL}/api/v3"
AUTHENTIK_ADMIN_EMAIL="${AUTHENTIK_ADMIN_EMAIL:-admin@example.com}"
AUTHENTIK_ADMIN_PASSWORD="${AUTHENTIK_ADMIN_PASSWORD:-}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"

DRY_RUN=false

# ==================== 服务配置 ====================
# 格式：名称|启动 URL|回调 URL|模式 (oidc/oauth2)
declare -a SERVICES=(
    "Grafana|https://grafana.example.com|https://grafana.example.com/login/generic_oauth|oidc"
    "Gitea|https://gitea.example.com|https://gitea.example.com/user/oauth2/Authentik/callback|oidc"
    "Nextcloud|https://nextcloud.example.com|https://nextcloud.example.com/apps/sociallogin/custom/oidc/Authentik|oidc"
    "Outline|https://outline.example.com|https://outline.example.com/auth/oidc/callback|oidc"
    "Open WebUI|https://webui.example.com|https://webui.example.com/oidc/callback|oidc"
    "Portainer|https://portainer.example.com|https://portainer.example.com|oauth2"
)

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== 参数解析 ====================
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            log_info "启用预览模式，不会实际创建资源"
            shift
            ;;
        --url)
            AUTHENTIK_URL="$2"
            AUTHENTIK_API_URL="${AUTHENTIK_URL}/api/v3"
            shift 2
            ;;
        --email)
            AUTHENTIK_ADMIN_EMAIL="$2"
            shift 2
            ;;
        --password)
            AUTHENTIK_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --token)
            AUTHENTIK_TOKEN="$2"
            shift 2
            ;;
        *)
            echo "未知参数：$1"
            echo "用法：$0 [--dry-run] [--url URL] [--email EMAIL] [--password PASSWORD] [--token TOKEN]"
            exit 1
            ;;
    esac
done

# ==================== 获取认证 Token ====================
get_auth_token() {
    if [[ -n "$AUTHENTIK_TOKEN" ]]; then
        echo "$AUTHENTIK_TOKEN"
        return
    fi
    
    if [[ -z "$AUTHENTIK_ADMIN_PASSWORD" ]]; then
        log_error "请设置 AUTHENTIK_TOKEN 或 AUTHENTIK_ADMIN_PASSWORD"
        exit 1
    fi
    
    log_info "获取认证 Token..."
    
    local response
    response=$(curl -s -X POST "${AUTHENTIK_API_URL}/core/access/" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"${AUTHENTIK_ADMIN_EMAIL}\",
            \"password\": \"${AUTHENTIK_ADMIN_PASSWORD}\"
        }")
    
    local token
    token=$(echo "$response" | jq -r '.token // empty')
    
    if [[ -z "$token" ]]; then
        log_error "获取 Token 失败：$response"
        exit 1
    fi
    
    echo "$token"
}

# ==================== API 调用封装 ====================
api_get() {
    local endpoint="$1"
    curl -s -X GET "${AUTHENTIK_API_URL}${endpoint}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json"
}

api_post() {
    local endpoint="$1"
    local data="$2"
    curl -s -X POST "${AUTHENTIK_API_URL}${endpoint}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$data"
}

api_put() {
    local endpoint="$1"
    local data="$2"
    curl -s -X PUT "${AUTHENTIK_API_URL}${endpoint}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$data"
}

# ==================== 获取/创建 Brand ====================
get_or_create_brand() {
    local brand_name="$1"
    
    log_info "检查 Brand: ${brand_name}..."
    
    local brands
    brands=$(api_get "/core/brands/?name=${brand_name}")
    local brand_id
    brand_id=$(echo "$brands" | jq -r '.results[0].brand_uuid // empty')
    
    if [[ -n "$brand_id" ]]; then
        log_ok "Brand 已存在：${brand_id}"
        echo "$brand_id"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将创建 Brand: ${brand_name}"
        echo "brand-dry-run-uuid"
        return
    fi
    
    log_info "创建 Brand: ${brand_name}..."
    local response
    response=$(api_post "/core/brands/" "{
        \"name\": \"${brand_name}\",
        \"domain\": \"${AUTHENTIK_URL#https://}\",
        \"default\": true
    }")
    
    local new_brand_id
    new_brand_id=$(echo "$response" | jq -r '.brand_uuid // empty')
    
    if [[ -z "$new_brand_id" ]]; then
        log_error "创建 Brand 失败：$response"
        exit 1
    fi
    
    log_ok "Brand 已创建：${new_brand_id}"
    echo "$new_brand_id"
}

# ==================== 获取/创建 Crypto Provider ====================
get_or_create_crypto_provider() {
    log_info "检查 Crypto Provider..."
    
    local providers
    providers=$(api_get "/crypto/providers/?name__icontains=default")
    local provider_id
    provider_id=$(echo "$providers" | jq -r '.results[0].pk // empty')
    
    if [[ -n "$provider_id" ]]; then
        log_ok "Crypto Provider 已存在：${provider_id}"
        echo "$provider_id"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "crypto-dry-run-id"
        return
    fi
    
    log_info "创建默认 Crypto Provider..."
    local response
    response=$(api_post "/crypto/providers/" "{
        \"name\": \"default\",
        \"signing_key\": \"RSA-2048\",
        \"verification_key\": \"RSA-2048\"
    }")
    
    local new_id
    new_id=$(echo "$response" | jq -r '.pk // empty')
    log_ok "Crypto Provider 已创建：${new_id}"
    echo "$new_id"
}

# ==================== 创建 OIDC Provider ====================
create_oidc_provider() {
    local name="$1"
    local redirect_uris="$2"
    local crypto_provider_id="$3"
    
    log_info "创建 OIDC Provider: ${name}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "provider-dry-run-${name}"
        return
    fi
    
    # 将 redirect_uris 字符串转换为 JSON 数组
    local redirect_array
    redirect_array=$(echo "$redirect_uris" | jq -R 'split(",")')
    
    local response
    response=$(api_post "/providers/oauth2/" "{
        \"name\": \"${name}\",
        \"authorization_flow\": \"$(api_get '/flows/instance/authorization/' | jq -r '.results[0].slug // \"default-provider-authorization-authorization\"')\",
        \"client_type\": \"confidential\",
        \"redirect_uris\": ${redirect_array},
        \"sub_mode\": \"hashed_user_id\",
        \"issuer_mode\": \"per_provider\",
        \"crypto_provider\": ${crypto_provider_id}
    }")
    
    local provider_id
    provider_id=$(echo "$response" | jq -r '.pk // empty')
    
    if [[ -z "$provider_id" ]]; then
        log_error "创建 Provider 失败：$response"
        exit 1
    fi
    
    local client_id
    client_id=$(echo "$response" | jq -r '.client_id // empty')
    local client_secret
    client_secret=$(echo "$response" | jq -r '.client_secret // empty')
    
    log_ok "OIDC Provider 已创建：${provider_id}"
    echo "${provider_id}|${client_id}|${client_secret}"
}

# ==================== 创建 Application ====================
create_application() {
    local name="$1"
    local slug="$2"
    local provider_id="$3"
    local open_url="$4"
    
    log_info "创建 Application: ${name}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    api_post "/core/applications/" "{
        \"name\": \"${name}\",
        \"slug\": \"${slug}\",
        \"provider\": ${provider_id},
        \"open_url\": \"${open_url}\",
        \"backchannel_provider\": null
    }" > /dev/null
    
    log_ok "Application 已创建：${name}"
}

# ==================== 创建用户组 ====================
create_group() {
    local group_name="$1"
    
    log_info "检查用户组：${group_name}..."
    
    local groups
    groups=$(api_get "/core/groups/?name=${group_name}")
    local group_id
    group_id=$(echo "$groups" | jq -r '.results[0].pk // empty')
    
    if [[ -n "$group_id" ]]; then
        log_ok "用户组已存在：${group_name}"
        echo "$group_id"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "group-dry-run-${group_name}"
        return
    fi
    
    log_info "创建用户组：${group_name}..."
    local response
    response=$(api_post "/core/groups/" "{
        \"name\": \"${group_name}\"
    }")
    
    local new_group_id
    new_group_id=$(echo "$response" | jq -r '.pk // empty')
    
    if [[ -z "$new_group_id" ]]; then
        log_error "创建用户组失败：$response"
        exit 1
    fi
    
    log_ok "用户组已创建：${group_name}"
    echo "$new_group_id"
}

# ==================== 主流程 ====================
main() {
    echo ""
    echo "========================================"
    echo "  Authentik OIDC Provider 自动配置工具"
    echo "========================================"
    echo ""
    
    # 获取认证 Token
    log_info "认证到 Authentik: ${AUTHENTIK_URL}"
    TOKEN=$(get_auth_token)
    log_ok "认证成功"
    
    # 获取/创建 Brand
    BRAND_ID=$(get_or_create_brand "Homelab")
    
    # 获取/创建 Crypto Provider
    CRYPTO_PROVIDER_ID=$(get_or_create_crypto_provider)
    
    # 创建用户组
    echo ""
    log_info "创建用户组..."
    ADMIN_GROUP_ID=$(create_group "homelab-admins")
    USER_GROUP_ID=$(create_group "homelab-users")
    MEDIA_GROUP_ID=$(create_group "media-users")
    
    # 为每个服务创建 Provider 和 Application
    echo ""
    log_info "开始创建 OIDC Providers..."
    echo ""
    
    # 输出表头
    printf "${YELLOW}%-15s | %-40s | %-20s | %-30s${NC}\n" "服务" "Client ID" "Client Secret" "Redirect URI"
    echo "--------------------------------------------------------------------------------"
    
    for service_config in "${SERVICES[@]}"; do
        IFS='|' read -r name redirect_uri mode <<< "$service_config"
        
        # 创建 Provider
        result=$(create_oidc_provider "$name" "$redirect_uri" "$CRYPTO_PROVIDER_ID")
        IFS='|' read -r provider_id client_id client_secret <<< "$result"
        
        # 创建 Application
        slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        create_application "$name" "$slug" "$provider_id" "$redirect_uri"
        
        # 输出凭据
        printf "${GREEN}%-15s${NC} | ${BLUE}%-40s${NC} | ${BLUE}%-20s${NC} | %s\n" \
            "$name" "$client_id" "$client_secret" "$redirect_uri"
    done
    
    echo ""
    echo "========================================"
    log_ok "所有 OIDC Provider 创建完成!"
    echo ""
    log_info "用户组已创建:"
    echo "  - homelab-admins (访问所有服务)"
    echo "  - homelab-users (访问普通服务)"
    echo "  - media-users (仅访问媒体服务)"
    echo ""
    log_info "下一步:"
    echo "  1. 将上述 Client ID/Secret 填入各服务的 .env 文件"
    echo "  2. 在各服务管理界面配置 OIDC"
    echo "  3. 在 Authentik 中配置用户组与应用的访问策略"
    echo ""
}

# 执行主流程
main
