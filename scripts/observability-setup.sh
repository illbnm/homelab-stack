#!/usr/bin/env bash
set -euo pipefail

# Observability Stack 完整部署脚本
# 下载 Grafana Dashboard JSON 文件，更新 .env 配置，并启动服务

#======================================================================
# 颜色定义
#======================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#======================================================================
# 配置
#======================================================================
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../stacks/observability" && pwd)"
DASHBOARD_DIR="${WORKDIR}/../config/grafana/provisioning/dashboards"
PROMETHEUS_ALERTS_DIR="${WORKDIR}/../config/prometheus/alerts"
PROMETHEUS_RULES_DIR="${WORKDIR}/../config/prometheus/rules"

# Grafana Dashboard IDs
DASHBOARDS=(
  "1860:node-exporter-full:Node Exporter Full.json"
  "179:docker-and-host-metrics:Docker Container & Host Metrics.json"
  "17346:traefik:Traefik Official.json"
  "13639:loki:Loki Dashboard.json"
  "18278:uptime-kuma:Uptime Kuma.json"
)

#======================================================================
# 函数
#======================================================================

log_info()   { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $*"; }

# 下载 Dashboard JSON
download_dashboard() {
  local id="$1"
  local name="$2"
  local filename="$3"

  local url="https://grafana.com/api/dashboards/${id}/revisions/latest/download"

  log_info "下载 Dashboard: ${name} (ID: ${id})..."
  if curl -sSL -o "${DASHBOARD_DIR}/${filename}" "${url}"; then
    log_info "✓ ${filename} 下载完成"
  else
    log_error "✗ ${filename} 下载失败"
    return 1
  fi
}

# 生成 alertmanager.yml（包含正确的 webhook URL）
generate_alertmanager_config() {
  local domain="${DOMAIN:-example.com}"
  local output="${WORKDIR}/../config/alertmanager/alertmanager.yml"

  log_info "生成 Alertmanager 配置 (DOMAIN=${domain})..."

  cat > "${output}" <<EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity', 'component', 'node']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'

  routes:
    - match:
        severity: 'critical'
      receiver: 'critical'
      continue: false
      group_wait: 10s
      repeat_interval: 1h

    - match:
        severity: 'warning'
      receiver: 'warning'
      continue: false

    - match:
        component: 'host'
      receiver: 'host-alerts'
      continue: true

    - match:
        component: 'container'
      receiver: 'container-alerts'
      continue: true

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://ntfy.${domain}:80'
        send_resolved: true

  - name: 'critical'
    webhook_configs:
      - url: 'http://ntfy.${domain}:80'
        send_resolved: true

  - name: 'warning'
    webhook_configs:
      - url: 'http://ntfy.${domain}:80'
        send_resolved: true

  - name: 'host-alerts'
    webhook_configs:
      - url: 'http://ntfy.${domain}:80'
        send_resolved: true

  - name: 'container-alerts'
    webhook_configs:
      - url: 'http://ntfy.${domain}:80'
        send_resolved: true

inhibit_rules:
  - source_match:
      alertname: 'ServiceDegraded'
    target_match_re:
      alertname: '.*'
    equal: ['service', 'component']
  - source_match:
      alertname: 'HostDown'
    target_match:
      component: 'container'
    equal: ['node']
EOF

  log_info "✓ Alertmanager 配置已生成"
}

# 检查 .env 文件
check_env() {
  if [[ ! -f "${WORKDIR}/.env" ]]; then
    log_warn ".env 文件不存在，从 .env.example 复制..."
    cp "${WORKDIR}/.env.example" "${WORKDIR}/.env"
    log_warn "请编辑 ${WORKDIR}/.env 设置以下变量："
    log_warn "  - DOMAIN (必填)"
    log_warn "  - ACME_EMAIL (必填)"
    log_warn "  - TRAEFIK_USER / TRAEFIK_PASSWORD"
    log_warn "  - TRAEFIK_BASIC_AUTH_HASH"
    exit 1
  fi

  # 加载 .env
  set -a
  source "${WORKDIR}/.env"
  set +a

  if [[ -z "${DOMAIN:-}" ]]; then
    log_error "DOMAIN 未设置！请在 ${WORKDIR}/.env 中设置"
    exit 1
  fi
}

#======================================================================
# 主流程
#======================================================================

main() {
  log_info "开始部署 Observability Stack..."

  # 1. 检查环境
  check_env

  # 2. 创建目录
  mkdir -p "${DASHBOARD_DIR}"
  mkdir -p "${PROMETHEUS_ALERTS_DIR}"
  mkdir -p "${PROMETHEUS_RULES_DIR}"

  # 3. 下载 Grafana Dashboards
  log_info "下载 Grafana Dashboards..."
  for entry in "${DASHBOARDS[@]}"; do
    IFS=':' read -r id name filename <<< "${entry}"
    download_dashboard "${id}" "${name}" "${filename}" || true
  done

  # 4. 生成 Alertmanager 配置
  generate_alertmanager_config

  # 5. 完成
  log_info "=========================================="
  log_info "Observability Stack 准备完成！"
  log_info "=========================================="
  log_info "下一步："
  log_info "  1. 确保 proxy 网络已存在: docker network create proxy"
  log_info "  2. 启动服务: cd ${WORKDIR} && docker compose up -d"
  log_info "  3. 验证: https://grafana.${DOMAIN}"
  log_info "  (默认账号: admin / admin，首次登录需修改密码)"
  log_info ""
  log_info "💡 提示：如需要 OIDC 集成，请在 .env 中配置 Authentik OAuth 并取消注释 grafana 环境变量"
}

main "$@"