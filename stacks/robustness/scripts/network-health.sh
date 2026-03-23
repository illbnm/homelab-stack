#!/bin/sh
# Homelab Stack #8 - 网络健康检查脚本
# 用于检测网络连通性、DNS 解析、镜像源可用性等

set -e

# 配置
TIMEOUT=${CONNECT_TIMEOUT:-5}
LOG_FILE=${LOG_FILE:-/var/log/network-health.log}

# 颜色输出 (如果终端支持)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# 日志函数
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date -Iseconds)
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$timestamp] [$level] $msg"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# 检查命令
print_status() {
    local name="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $name"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $name${details:+ - $details}"
    else
        echo -e "${RED}✗${NC} $name${details:+ - $details}"
    fi
}

# 检查 DNS 解析
check_dns() {
    local domain="$1"
    local dns_server="${2:-}"
    
    if [ -n "$dns_server" ]; then
        if nslookup "$domain" "$dns_server" > /dev/null 2>&1; then
            return 0
        fi
    else
        if nslookup "$domain" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# 检查 HTTP 连通性
check_http() {
    local url="$1"
    if curl -sf --connect-timeout "$TIMEOUT" --head "$url" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# 检查 Docker Hub 连通性
check_docker_hub() {
    if check_http "https://hub.docker.com"; then
        return 0
    fi
    return 1
}

# 检查 GitHub 连通性
check_github() {
    if check_http "https://github.com"; then
        return 0
    fi
    return 1
}

# 检查镜像源可用性
check_mirror() {
    local mirror="$1"
    if curl -sf --connect-timeout "$TIMEOUT" "${mirror}/v2/_catalog" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# 检查 NTP 时间同步
check_ntp() {
    local ntp_server="$1"
    if command -v ntpdate > /dev/null 2>&1; then
        if ntpdate -q "$ntp_server" > /dev/null 2>&1; then
            return 0
        fi
    elif command -v chronyc > /dev/null 2>&1; then
        if chronyc tracking > /dev/null 2>&1; then
            return 0
        fi
    fi
    # 降级检查：简单的 ping
    if ping -c 1 -W "$TIMEOUT" "$ntp_server" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# 运行所有检查
run_all_checks() {
    local issues=0
    
    echo "========================================"
    echo "  Homelab 网络健康检查"
    echo "  时间：$(date -Iseconds)"
    echo "========================================"
    echo ""
    
    # DNS 检查
    echo "【DNS 解析检查】"
    if check_dns "www.baidu.com" "223.5.5.5"; then
        print_status "阿里 DNS (223.5.5.5)" "OK"
    else
        print_status "阿里 DNS (223.5.5.5)" "FAIL"
        issues=$((issues + 1))
    fi
    
    if check_dns "www.baidu.com" "119.29.29.29"; then
        print_status "腾讯 DNSPod (119.29.29.29)" "OK"
    else
        print_status "腾讯 DNSPod (119.29.29.29)" "FAIL"
        issues=$((issues + 1))
    fi
    
    echo ""
    
    # 外网连通性检查
    echo "【外网连通性检查】"
    if check_docker_hub; then
        print_status "Docker Hub" "OK"
    else
        print_status "Docker Hub" "WARN" "可能需要使用镜像源"
        issues=$((issues + 1))
    fi
    
    if check_github; then
        print_status "GitHub" "OK"
    else
        print_status "GitHub" "WARN" "可能需要使用代理或镜像"
        issues=$((issues + 1))
    fi
    
    echo ""
    
    # 镜像源检查
    echo "【镜像源可用性检查】"
    for mirror in "docker.m.daocloud.io" "docker.mirrors.ustc.edu.cn" "registry.docker-cn.com" "hub-mirror.c.163.com"; do
        if check_mirror "$mirror"; then
            print_status "$mirror" "OK"
        else
            print_status "$mirror" "WARN" "不可用"
        fi
    done
    
    echo ""
    
    # NTP 时间同步检查
    echo "【NTP 时间同步检查】"
    for ntp in "ntp.aliyun.com" "ntp.tencent.com" "cn.pool.ntp.org"; do
        if check_ntp "$ntp"; then
            print_status "$ntp" "OK"
        else
            print_status "$ntp" "WARN" "无法同步"
        fi
    done
    
    echo ""
    echo "========================================"
    
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}所有检查通过!${NC}"
        return 0
    else
        echo -e "${YELLOW}发现 $issues 个问题${NC}"
        return 1
    fi
}

# 持续监控模式
monitor_mode() {
    local interval="${1:-60}"
    
    log_info "启动网络监控模式 (间隔：${interval}秒)"
    
    while true; do
        run_all_checks > /dev/null 2>&1
        local status=$?
        
        if [ $status -ne 0 ]; then
            log_warn "网络检查发现异常"
        else
            log_info "网络检查正常"
        fi
        
        sleep "$interval"
    done
}

# 显示帮助
show_help() {
    cat << EOF
Homelab 网络健康检查工具

用法:
  $0 check              运行所有检查
  $0 dns <domain>       检查 DNS 解析
  $0 http <url>         检查 HTTP 连通性
  $0 docker-hub         检查 Docker Hub 连通性
  $0 github             检查 GitHub 连通性
  $0 mirror <url>       检查镜像源可用性
  $0 ntp <server>       检查 NTP 服务器
  $0 monitor [interval] 持续监控模式 (默认间隔 60 秒)
  $0 help               显示此帮助信息

示例:
  $0 check
  $0 dns www.baidu.com
  $0 http https://hub.docker.com
  $0 mirror docker.m.daocloud.io
  $0 monitor 30

EOF
}

# 主入口
case "${1:-check}" in
    check)
        run_all_checks
        ;;
    dns)
        if [ -z "$2" ]; then
            echo "错误：请指定域名"
            exit 1
        fi
        if check_dns "$2"; then
            print_status "DNS 解析：$2" "OK"
        else
            print_status "DNS 解析：$2" "FAIL"
            exit 1
        fi
        ;;
    http)
        if [ -z "$2" ]; then
            echo "错误：请指定 URL"
            exit 1
        fi
        if check_http "$2"; then
            print_status "HTTP 连通：$2" "OK"
        else
            print_status "HTTP 连通：$2" "FAIL"
            exit 1
        fi
        ;;
    docker-hub)
        if check_docker_hub; then
            print_status "Docker Hub" "OK"
        else
            print_status "Docker Hub" "FAIL"
            exit 1
        fi
        ;;
    github)
        if check_github; then
            print_status "GitHub" "OK"
        else
            print_status "GitHub" "FAIL"
            exit 1
        fi
        ;;
    mirror)
        if [ -z "$2" ]; then
            echo "错误：请指定镜像源 URL"
            exit 1
        fi
        if check_mirror "$2"; then
            print_status "镜像源：$2" "OK"
        else
            print_status "镜像源：$2" "FAIL"
            exit 1
        fi
        ;;
    ntp)
        if [ -z "$2" ]; then
            echo "错误：请指定 NTP 服务器"
            exit 1
        fi
        if check_ntp "$2"; then
            print_status "NTP：$2" "OK"
        else
            print_status "NTP：$2" "FAIL"
            exit 1
        fi
        ;;
    monitor)
        monitor_mode "${2:-60}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "未知命令：$1"
        show_help
        exit 1
        ;;
esac
