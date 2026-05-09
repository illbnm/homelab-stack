#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Testing Framework
# Usage: ./scripts/test-stacks.sh [stack_name|all] [--quick]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
PASS=0; FAIL=0

ok()   { echo -e "  ${GREEN}✓${RESET} $*"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${RESET} $*"; ((FAIL++)); }

check_service() {
  local name="$1" url="${2:-}" check_type="${3:-http}"
  
  case "$check_type" in
    http)
      if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
        ok "$name ($url)"
      else
        fail "$name ($url) unreachable"
      fi
      ;;
    container)
      if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        local status=$(docker inspect "$name" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
        if [ "$status" = "healthy" ]; then
          ok "$name (healthy)"
        else
          fail "$name ($status)"
        fi
      else
        fail "$name not running"
      fi
      ;;
    port)
      if ss -tuln | grep -q ":$url "; then
        ok "$name (port $url listening)"
      else
        fail "$name (port $url not listening)"
      fi
      ;;
  esac
}

TARGET="${1:-all}"
QUICK=false
[[ "${2:-}" == "--quick" ]] && QUICK=true

echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
echo -e "${CYAN}║   HomeLab Stack Test Runner     ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
echo ""

if [ "$TARGET" = "all" ] || [ "$TARGET" = "base" ]; then
  echo -e "${YELLOW}── Base Infrastructure ──${RESET}"
  check_service "traefik" "" container
  check_service "portainer" "" container
  check_service "watchtower" "" container
fi

if [ "$TARGET" = "all" ] || [ "$TARGET" = "databases" ]; then
  echo -e "${YELLOW}── Databases ──${RESET}"
  check_service "homelab-postgres" "" container
  check_service "homelab-redis" "" container
  check_service "homelab-mariadb" "" container
fi

if [ "$TARGET" = "all" ] || [ "$TARGET" = "sso" ]; then
  echo -e "${YELLOW}── SSO ──${RESET}"
  check_service "authentik-server" "" container
fi

if [ "$TARGET" = "all" ] || [ "$TARGET" = "notifications" ]; then
  echo -e "${YELLOW}── Notifications ──${RESET}"
  check_service "ntfy" "" container
  # Test notification script
  if "$SCRIPT_DIR/notify.sh" test "TestRunner" "Automated health check" default heartbeat 2>/dev/null; then
    ok "notify.sh"
  else
    fail "notify.sh"
  fi
fi

if [ "$TARGET" = "all" ] || [ "$TARGET" = "backup" ]; then
  echo -e "${YELLOW}── Backup ──${RESET}"
  if "$SCRIPT_DIR/backup.sh" --list > /dev/null 2>&1; then
    ok "backup.sh --list"
  else
    fail "backup.sh --list"
  fi
  if "$SCRIPT_DIR/backup.sh" --verify > /dev/null 2>&1; then
    ok "backup.sh --verify"
  else
    fail "backup.sh --verify (no backups yet)"
  fi
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════${RESET}"
echo -e "  ${GREEN}Passed: $PASS${RESET}  ${RED}Failed: $FAIL${RESET}"
echo -e "${CYAN}═══════════════════════════════════${RESET}"

exit $FAIL
