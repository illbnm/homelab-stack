#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
FAILURES=0
SLOW=0

status_line() {
  local status=$1 name=$2 detail=$3 color
  case "$status" in
    OK) color=$GREEN ;;
    SLOW) color=$YELLOW; SLOW=$((SLOW + 1)) ;;
    FAIL) color=$RED; FAILURES=$((FAILURES + 1)) ;;
    *) color=$BLUE ;;
  esac
  printf '%b%-5s%b %-24s %s\n' "$color" "$status" "$NC" "$name" "$detail"
}

check_https() {
  local name=$1 url=$2 start_ms elapsed_ms code
  start_ms=$(date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)")
  code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "$url" 2>/dev/null || printf '000')
  elapsed_ms=$((($(date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)")) - start_ms))
  if [[ "$code" =~ ^[23] ]]; then
    if [[ "$elapsed_ms" -gt 5000 ]]; then
      status_line SLOW "$name" "${elapsed_ms}ms HTTP $code $url"
    else
      status_line OK "$name" "${elapsed_ms}ms HTTP $code $url"
    fi
  else
    status_line FAIL "$name" "HTTP $code $url"
  fi
}

check_dns() {
  local host=${1:-github.com}
  if getent hosts "$host" >/dev/null 2>&1 || nslookup "$host" >/dev/null 2>&1; then
    status_line OK DNS "$host resolves"
  else
    status_line FAIL DNS "$host does not resolve"
  fi
}

check_port() {
  local name=$1 host=$2 port=$3
  if timeout 5 bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1; then
    status_line OK "$name" "$host:$port reachable"
  else
    status_line FAIL "$name" "$host:$port unreachable"
  fi
}

main() {
  printf '%bHomeLab connectivity check%b\n\n' "$BLUE" "$NC"
  check_dns github.com
  check_https "Docker Hub" "https://registry-1.docker.io/v2/"
  check_https GitHub "https://github.com/"
  check_https "gcr.io" "https://gcr.io/v2/"
  check_https "ghcr.io" "https://ghcr.io/v2/"
  check_port "Outbound HTTP" example.com 80
  check_port "Outbound HTTPS" example.com 443
  printf '\nSummary: %s slow, %s failed\n' "$SLOW" "$FAILURES"
  if [[ "$FAILURES" -gt 0 || "$SLOW" -gt 0 ]]; then
    printf '%bRecommendation:%b run scripts/setup-cn-mirrors.sh and scripts/localize-images.sh --cn if you are on a restricted or slow network.\n' "$YELLOW" "$NC"
  fi
  [[ "$FAILURES" -eq 0 ]]
}

main "$@"
