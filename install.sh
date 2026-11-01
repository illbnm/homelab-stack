#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "Installation failed. Check logs at ~/.homelab/install.log"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo -e ""
echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
echo -e "${BOLD}                    S T A C K   v1.0.0${NC}"
echo -e ""

# ---------------------------------------------------------------------------
# Step 1: Check dependencies
# ---------------------------------------------------------------------------
log_step "Checking dependencies"
bash "$(dirname "$0")/scripts/check-deps.sh"

# ---------------------------------------------------------------------------
# Step 2: CN network detection
# ---------------------------------------------------------------------------
log_step "Network environment detection"
bash "$(dirname "$0")/scripts/check-connectivity.sh" || true

# ---------------------------------------------------------------------------
# Step 2b: CN mirror setup (国内网络适配)
# ---------------------------------------------------------------------------
if [[ -f "$(dirname "$0")/scripts/setup-cn-mirrors.sh" ]]; then
  log_step "CN mirror setup (国内网络镜像配置)"
  bash "$(dirname "$0")/scripts/setup-cn-mirrors.sh" || log_warn "CN mirror setup 未完全成功（可选，不影响核心部署）"
fi

# ---------------------------------------------------------------------------
# Step 3: Setup environment
# ---------------------------------------------------------------------------
log_step "Environment configuration"
if [[ ! -f .env ]]; then
  bash "$(dirname "$0")/scripts/setup-env.sh"
else
  log_warn ".env already exists, skipping setup. Remove it to reconfigure."
fi

# ---------------------------------------------------------------------------
# Step 4: Create data directories
# ---------------------------------------------------------------------------
log_step "Creating data directories"
mkdir -p \
  data/traefik/certs \
  data/portainer \
  data/prometheus \
  data/grafana \
  data/loki \
  data/authentik/media \
  data/nextcloud \
  data/gitea \
  data/vaultwarden

chmod 600 config/traefik/acme.json 2>/dev/null || touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# ---------------------------------------------------------------------------
# Step 5: Launch base infrastructure
# ---------------------------------------------------------------------------
log_step "Launching base infrastructure"
docker compose -f docker-compose.base.yml up -d

# 等待基础服务健康（可选，超时 300s 不阻塞）
if [[ -f "$(dirname "$0")/scripts/wait-healthy.sh" ]]; then
  log_step "Waiting for base infrastructure healthy"
  bash "$(dirname "$0")/scripts/wait-healthy.sh" --stack base --dir . --timeout 300 || log_warn "部分容器未在 300s 内健康（可用 scripts/diagnose.sh 诊断）"
fi

log_info ""
log_info "${GREEN}${BOLD}✓ Base infrastructure is up!${NC}"
log_info ""
log_info "Next steps:"
log_info "  ./scripts/stack-manager.sh start sso        # Set up SSO first (recommended)"
log_info "  ./scripts/stack-manager.sh start monitoring # Launch monitoring"
log_info "  ./scripts/stack-manager.sh list             # See all available stacks"
log_info ""
log_info "Documentation: docs/getting-started.md"
