#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# =============================================================================
# Usage:
#   ./run-tests.sh                    # Run all stacks
#   ./run-tests.sh --stack base       # Run only base stack tests
#   ./run-tests.sh --stack media,db   # Run specific stacks
#   ./run-tests.sh --all              # Run all (same as no args)
#   ./run-tests.sh --ci               # CI mode (fail-fast, JSON output)
#   ./run-tests.sh --quick            # Skip slow e2e tests
#   ./run-tests.sh --dry-run          # Show what would run, don't execute
#   ./run-tests.sh --list             # List available test suites
#
# Environment:
#   FAIL_FAST=1       Abort on first failure
#   TEST_TIMEOUT=120  Per-stack timeout in seconds
#   BASE_URL          Override base URL (default: http://localhost)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

# Load libraries
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
RUN_STACKS="all"
CI_MODE=0
QUICK_MODE=0
DRY_RUN=0
LIST_ONLY=0
BASE_URL="${BASE_URL:-http://localhost}"
TEST_TIMEOUT="${TEST_TIMEOUT:-120}"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      RUN_STACKS="$2"
      shift 2
      ;;
    --all)
      RUN_STACKS="all"
      shift
      ;;
    --ci)
      CI_MODE=1
      FAIL_FAST=1
      export FAIL_FAST
      shift
      ;;
    --quick)
      QUICK_MODE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    --help|-h)
      head -17 "$0" | tail -14
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Available test suites
# ---------------------------------------------------------------------------
declare -A SUITES=(
  [base]="基础设施: Traefik + Portainer + Watchtower"
  [media]="媒体栈: Jellyfin + Sonarr + Radarr + qBittorrent + Prowlarr"
  [storage]="存储栈: Nextcloud + MinIO + FileBrowser"
  [monitoring]="监控栈: Prometheus + Grafana + Loki + Alertmanager"
  [network]="网络栈: AdGuard + WireGuard + Nginx Proxy Manager"
  [productivity]="生产力: Gitea + Vaultwarden + Outline + BookStack"
  [ai]="AI 栈: Ollama + Open WebUI + Stable Diffusion"
  [sso]="SSO: Authentik 统一认证"
  [databases]="数据库: PostgreSQL + Redis + MariaDB"
  [notifications]="通知: ntfy + Apprise"
  [home-automation]="智能家居: Home Assistant + Node-RED + Zigbee2MQTT"
  [dashboard]="仪表盘: Homarr + Homepage"
)

declare -A SUITE_ORDER=(
  0=base 1=databases 2=sso 3=monitoring 4=network 5=media
  6=storage 7=productivity 8=ai 9=home-automation 10=notifications 11=dashboard
)

# ---------------------------------------------------------------------------
if [[ "$LIST_ONLY" == "1" ]]; then
  echo "Available test suites:"
  for i in $(seq 0 11); do
    s="${SUITE_ORDER[$i]}"
    echo "  $s — ${SUITES[$s]}"
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Report init
# ---------------------------------------------------------------------------
RESULTS_DIR="${SCRIPT_DIR}/results"
report_init "$RESULTS_DIR"

# ---------------------------------------------------------------------------
# Docker preflight
# ---------------------------------------------------------------------------
if ! docker info &>/dev/null; then
  echo -e "${_A_RED}ERROR: Docker is not running or not accessible.${_A_NC}"
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo -e "\n${_A_YELLOW}DRY RUN — showing what would execute:${_A_NC}"
  for i in $(seq 0 11); do
    s="${SUITE_ORDER[$i]}"
    if should_run_stack "$s"; then
      echo "  ✓ ${s}.test.sh — ${SUITES[$s]}"
    else
      echo "  ~ ${s}.test.sh (skipped)"
    fi
  done
  if [[ "$QUICK_MODE" != "1" ]]; then
    echo "  ✓ e2e/sso-flow.test.sh — SSO 端到端流程"
    echo "  ✓ e2e/backup-restore.test.sh — 备份恢复端到端"
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Run stack tests
# ---------------------------------------------------------------------------
for i in $(seq 0 11); do
  s="${SUITE_ORDER[$i]}"
  if should_run_stack "$s"; then
    test_file="${SCRIPT_DIR}/stacks/${s}.test.sh"
    if [[ -f "$test_file" ]]; then
      echo -e "\n${_A_BOLD}Running: ${s}${_A_NC}"
      if ! timeout "$TEST_TIMEOUT" bash "$test_file" 2>&1; then
        echo -e "${_A_YELLOW}⚠ Stack '${s}' exited with non-zero${_A_NC}"
      fi
    else
      echo -e "${_A_YELLOW}⚠ Test file missing: ${test_file}${_A_NC}"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Run e2e tests (unless --quick)
# ---------------------------------------------------------------------------
if [[ "$QUICK_MODE" != "1" ]]; then
  for e2e_file in "${SCRIPT_DIR}/e2e/"*.test.sh; do
    [[ -f "$e2e_file" ]] || continue
    name=$(basename "$e2e_file" .test.sh)
    echo -e "\n${_A_BOLD}Running e2e: ${name}${_A_NC}"
    timeout "$TEST_TIMEOUT" bash "$e2e_file" 2>&1 || true
  done
fi

# ---------------------------------------------------------------------------
# Final report
# ---------------------------------------------------------------------------
report_finish
exit $?
