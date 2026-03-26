#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — 网络连通性检测
# 检测 Docker Hub、GitHub、gcr.io、ghcr.io、DNS、常用端口的可达性
# 输出格式: [OK] / [SLOW] / [FAIL]
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

RED_H='\033[0;31m'; GREEN_H='\033[0;32m'; YELLOW_H='\033[1;33m'; NC_H='\033[0m'

OK_MARK="${GREEN}[OK]${NC}"
SLOW_MARK="${YELLOW}[SLOW]${NC}"
FAIL_MARK="${RED}[FAIL]${NC}"

# 超时配置
CONNECT_TIMEOUT=5
MAX_TIME=10

# DNS 服务器
DNS_SERVER="${DNS_SERVER:-8.8.8.8}"

# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------

check_url() {
  local url="$1"
  local name="$2"
  local timeout="${3:-$MAX_TIME}"
  local connect_timeout="${4:-$CONNECT_TIMEOUT}"

  local start_time
  start_time=$(date +%s.%N)

  local http_code
  http_code=$(curl -sfL --connect-timeout "$connect_timeout" \
    --max-time "$timeout" \
    -o /dev/null \
    -w "%{http_code}" \
    "$url" 2>/dev/null || echo "000")

  local end_time
  end_time=$(date +%s.%N)
  local elapsed
  elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "99")

  if [[ "$http_code" =~ ^[23] ]]; then
    if (( $(echo "$elapsed < 3" | bc -l 2>/dev/null || echo 0) )); then
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    else
      printf "%-40s %s (%.1fs)\n" "$name" "$SLOW_MARK" "$elapsed"
      return 1
    fi
  else
    printf "%-40s %s (HTTP $http_code)\n" "$name" "$FAIL_MARK"
    return 2
  fi
}

check_port() {
  local host="$1"
  local port="$2"
  local name="${3:-${host}:${port}}"

  local start_time
  start_time=$(date +%s.%N)

  # 使用 bash 内置 /dev/tcp（如果支持）或 nc
  if command -v nc &>/dev/null; then
    if nc -z -w"$CONNECT_TIMEOUT" "$host" "$port" 2>/dev/null; then
      local end_time
      end_time=$(date +%s.%N)
      local elapsed
      elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    fi
  elif command -v timeout &>/dev/null; then
    if timeout "$CONNECT_TIMEOUT" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
      local end_time
      end_time=$(date +%s.%N)
      local elapsed
      elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    fi
  fi

  printf "%-40s %s\n" "$name" "$FAIL_MARK"
  return 2
}

check_dns() {
  local domain="$1"
  local name="${2:-DNS: ${domain}}"

  local start_time
  start_time=$(date +%s.%N)

  if command -v nslookup &>/dev/null; then
    if nslookup "$domain" "$DNS_SERVER" &>/dev/null; then
      local end_time
      end_time=$(date +%s.%N)
      local elapsed
      elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    fi
  elif command -v dig &>/dev/null; then
    if dig +time="$CONNECT_TIMEOUT" +tries=1 "$domain" @"$DNS_SERVER" &>/dev/null; then
      local end_time
      end_time=$(date +%s.%N)
      local elapsed
      elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    fi
  elif command -v getent &>/dev/null; then
    if getent hosts "$domain" &>/dev/null; then
      local end_time
      end_time=$(date +%s.%N)
      local elapsed
      elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    fi
  fi

  printf "%-40s %s\n" "$name" "$FAIL_MARK"
  return 2
}

check_ping() {
  local host="$1"
  local name="${2:-Ping: ${host}}"

  if command -v ping &>/dev/null; then
    local start_time
    start_time=$(date +%s.%N)
    local loss
    loss=$(ping -c 3 -W "$CONNECT_TIMEOUT" "$host" 2>/dev/null | grep -o '[0-9]*% packet loss' | grep -o '[0-9]*' || echo "100")

    local end_time
    end_time=$(date +%s.%N)
    local elapsed
    elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")

    if [[ "$loss" -eq 0 ]]; then
      printf "%-40s %s (%.1fs)\n" "$name" "$OK_MARK" "$elapsed"
      return 0
    elif [[ "$loss" -lt 100 ]]; then
      printf "%-40s %s (${loss}% loss)\n" "$name" "$SLOW_MARK"
      return 1
    else
      printf "%-40s %s\n" "$name" "$FAIL_MARK"
      return 2
    fi
  fi

  # 回退到 curl
  check_url "https://$host" "$name"
}

# ---------------------------------------------------------------------------
# 检测逻辑
# ---------------------------------------------------------------------------

check_docker_hub() {
  echo ""
  echo -e "${BLUE}=== Docker Hub 相关 ===${NC}"

  check_dns "registry-1.docker.io" "DNS: registry-1.docker.io"
  check_ping "registry-1.docker.io" "Ping: registry-1.docker.io"
  check_url "https://registry-1.docker.io/v2/" "Docker Hub API (HTTPS)"
  check_url "https://hub.docker.com/" "Docker Hub Website"
}

check_github() {
  echo ""
  echo -e "${BLUE}=== GitHub 相关 ===${NC}"

  check_dns "github.com" "DNS: github.com"
  check_ping "github.com" "Ping: github.com"
  check_url "https://api.github.com/" "GitHub API"
  check_url "https://github.com/" "GitHub Website"
}

check_gcr_ghcr() {
  echo ""
  echo -e "${BLUE}=== gcr.io / ghcr.io ===${NC}"

  check_dns "gcr.io" "DNS: gcr.io"
  check_url "https://gcr.io/v2/" "gcr.io API"

  check_dns "ghcr.io" "DNS: ghcr.io"
  check_url "https://ghcr.io/v2/" "ghcr.io API"
}

check_cn_mirrors() {
  echo ""
  echo -e "${BLUE}=== 国内镜像源 ===${NC}"

  check_url "https://docker.m.daocloud.io/v2/" "DaoCloud Mirror (HTTPS)"
  check_url "https://hub-mirror.c.163.com/v2/" "163 Mirror API"
  check_url "https://mirror.baidubce.com/" "Baidu BCE Mirror"

  echo ""
  echo -e "${BLUE}=== 端口检测 (443) ===${NC}"
  check_port "gcr.io" 443 "Port: gcr.io:443"
  check_port "ghcr.io" 443 "Port: ghcr.io:443"
  check_port "docker.m.daocloud.io" 443 "Port: docker.m.daocloud.io:443"
  check_port "hub-mirror.c.163.com" 443 "Port: hub-mirror.c.163.com:443"
}

check_dns_servers() {
  echo ""
  echo -e "${BLUE}=== DNS 解析 ===${NC}"

  check_dns "www.google.com" "DNS: google.com"
  check_dns "www.baidu.com" "DNS: baidu.com"
  check_dns "github.com" "DNS: github.com"
  check_dns "docker.io" "DNS: docker.io"
}

check_basic_ports() {
  echo ""
  echo -e "${BLUE}=== 常用端口检测 ===${NC}"

  check_port "8.8.8.8" 53 "DNS: 8.8.8.8:53"
  check_port "1.1.1.1" 53 "DNS: 1.1.1.1:53"

  # 检测本地 Docker 相关端口
  if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo "  [INFO] Docker daemon is running"
  fi
}

# ---------------------------------------------------------------------------
# 主函数
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
用法: check-connectivity.sh [选项]

检测网络连通性，包括 Docker Hub、GitHub、gcr.io、ghcr.io、
国内镜像源、DNS 和常用端口。

选项:
  --docker-hub   仅检测 Docker Hub 相关
  --github       仅检测 GitHub 相关
  --gcr-ghcr     仅检测 gcr.io / ghcr.io
  --cn-mirrors   仅检测国内镜像源
  --dns          仅检测 DNS
  --quick        快速检测（减少超时等待）
  --json         JSON 格式输出
  -h, --help     显示帮助

示例:
  ./check-connectivity.sh              # 完整检测
  ./check-connectivity.sh --quick     # 快速检测
  ./check-connectivity.sh --json      # JSON 格式
EOF
}

main() {
  local mode="full"
  local quick=false
  local json=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --docker-hub) mode="docker-hub" ;;
      --github)     mode="github" ;;
      --gcr-ghcr)   mode="gcr-ghcr" ;;
      --cn-mirrors) mode="cn-mirrors" ;;
      --dns)        mode="dns" ;;
      --quick)      quick=true ;;
      --json)       json=true ;;
      -h|--help)    usage; exit 0 ;;
      *)            echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done

  if [[ "$quick" == "true" ]]; then
    CONNECT_TIMEOUT=2
    MAX_TIME=5
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  网络连通性检测${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""

  case "$mode" in
    docker-hub)  check_docker_hub ;;
    github)      check_github ;;
    gcr-ghcr)    check_gcr_ghcr ;;
    cn-mirrors)  check_cn_mirrors ;;
    dns)         check_dns_servers ;;
    full)
      check_dns_servers
      check_basic_ports
      check_docker_hub
      check_github
      check_gcr_ghcr
      check_cn_mirrors
      ;;
  esac

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  检测完成${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "检测时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
}

main "$@"
