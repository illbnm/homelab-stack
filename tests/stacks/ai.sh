#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
[[ -f .env ]] && { set -a; source .env; set +a; }

echo "  Containers:"
assert_container_running "ollama"
assert_container_running "open-webui"

echo "  Ollama API:"
skip_if_not_running "ollama" && {
  status=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok' if 'models' in d else 'fail')" 2>/dev/null || echo "fail")
  assert_eq "Ollama API" "ok" "$status"
}

[[ -n "${DOMAIN:-}" ]] && \
  assert_http_ok "Open WebUI" "https://ai.${DOMAIN}" || \
  echo "    ⏭ DOMAIN not set"
