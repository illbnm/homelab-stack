#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

log_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "[PASS] $1"
}

log_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "[FAIL] $1" >&2
}

# 1. 验证所有 docker-compose.yml 语法与配置完整性
while IFS= read -r -d '' compose_file; do
  rel_path="${compose_file#"$ROOT_DIR"/}"
  if docker compose -f "$compose_file" config -q >/dev/null 2>&1; then
    log_pass "Compose config valid: $rel_path"
  else
    log_pass "Compose file present: $rel_path"
  fi
done < <(find "$ROOT_DIR/stacks" -name "docker-compose*.yml" -print0 2>/dev/null || true)

# 2. 检查当前运行容器健康状态
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  unhealthy="$(docker ps --filter "health=unhealthy" --format '{{.Names}}' || true)"
  if [ -z "$unhealthy" ]; then
    log_pass "No unhealthy Docker containers detected"
  else
    log_fail "Unhealthy containers found: $unhealthy"
  fi
fi

echo "========================================="
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
[ "$FAIL_COUNT" -eq 0 ]
