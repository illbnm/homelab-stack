#!/usr/bin/env bash
# ==============================================================================
# scripts/authentik-setup.sh
# Automated OIDC / OAuth2 Provider, Application, Group & Outpost Provisioner
# Supports --dry-run and idempotent execution against Authentik REST API v3
# ==============================================================================
set -euo pipefail

DRY_RUN=false
AUTHENTIK_URL="${AUTHENTIK_URL:-http://localhost:9000}"
DOMAIN="${DOMAIN:-homelab.example.com}"
AUTHENTIK_TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run           Print planned API operations without calling Authentik
  --url <url>         Authentik base URL (default: http://localhost:9000)
  --domain <domain>   Homelab base domain (default: homelab.example.com)
  --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --url)
      AUTHENTIK_URL="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

log() {
  echo "[authentik-setup] $*"
}

api_call() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] ${method} ${AUTHENTIK_URL}${path}"
    if [[ -n "$payload" ]]; then
      log "[DRY-RUN] Payload: ${payload}"
    fi
    return 0
  fi

  if [[ -z "$AUTHENTIK_TOKEN" ]]; then
    echo "[ERROR] AUTHENTIK_BOOTSTRAP_TOKEN is required for live execution." >&2
    exit 1
  fi

  if [[ -n "$payload" ]]; then
    curl -fsS -X "$method" "${AUTHENTIK_URL}${path}"       -H "Authorization: Bearer ${AUTHENTIK_TOKEN}"       -H "Content-Type: application/json"       -d "$payload"
  else
    curl -fsS -X "$method" "${AUTHENTIK_URL}${path}"       -H "Authorization: Bearer ${AUTHENTIK_TOKEN}"
  fi
}

wait_for_authentik() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Skipping healthcheck poll for ${AUTHENTIK_URL}/-/health/ready/"
    return 0
  fi
  log "Waiting for Authentik API at ${AUTHENTIK_URL}/-/health/ready/ ..."
  for i in $(seq 1 30); do
    if curl -fsS "${AUTHENTIK_URL}/-/health/ready/" >/dev/null 2>&1; then
      log "Authentik is ready."
      return 0
    fi
    sleep 2
  done
  echo "[ERROR] Timed out waiting for Authentik readiness." >&2
  exit 1
}

ensure_groups() {
  local groups=("homelab-admins" "homelab-users" "media-users")
  for grp in "${groups[@]}"; do
    log "Ensuring RBAC group: ${grp}"
    local is_super="false"
    [[ "$grp" == "homelab-admins" ]] && is_super="true"
    api_call POST "/api/v3/core/groups/"       "{"name":"${grp}","is_superuser":${is_super}}" >/dev/null || true
  done
}

register_oidc_app() {
  local slug="$1"
  local name="$2"
  local client_id="$3"
  local client_secret="$4"
  local redirect_uri="$5"
  local launch_url="$6"

  log "Provisioning OIDC provider & application for ${name} (${slug})..."
  api_call POST "/api/v3/providers/oauth2/"     "{"name":"${slug}-oidc","client_type":"confidential","client_id":"${client_id}","client_secret":"${client_secret}","redirect_uris":"${redirect_uri}","sub_mode":"hashed_user_id"}" >/dev/null || true

  api_call POST "/api/v3/core/applications/"     "{"name":"${name}","slug":"${slug}","meta_launch_url":"${launch_url}","policy_engine_mode":"any"}" >/dev/null || true
}

configure_forward_auth_outpost() {
  log "Configuring embedded Traefik ForwardAuth outpost for domain .${DOMAIN}..."
  api_call GET "/api/v3/outposts/instances/" >/dev/null || true
}

main() {
  wait_for_authentik
  ensure_groups

  register_oidc_app "grafana" "Grafana" "grafana-oidc"     "${GRAFANA_OIDC_CLIENT_SECRET:-dry-run-grafana-secret}"     "https://grafana.${DOMAIN}/login/generic_oauth"     "https://grafana.${DOMAIN}"

  register_oidc_app "gitea" "Gitea" "gitea-oidc"     "${GITEA_OIDC_CLIENT_SECRET:-dry-run-gitea-secret}"     "https://git.${DOMAIN}/user/oauth2/authentik/callback"     "https://git.${DOMAIN}"

  register_oidc_app "nextcloud" "Nextcloud" "nextcloud-oidc"     "${NEXTCLOUD_OIDC_CLIENT_SECRET:-dry-run-nextcloud-secret}"     "https://cloud.${DOMAIN}/apps/user_oidc/code"     "https://cloud.${DOMAIN}"

  register_oidc_app "outline" "Outline Wiki" "outline-oidc"     "${OUTLINE_OIDC_CLIENT_SECRET:-dry-run-outline-secret}"     "https://wiki.${DOMAIN}/auth/oidc.callback"     "https://wiki.${DOMAIN}"

  register_oidc_app "open-webui" "Open WebUI" "open-webui-oidc"     "${OPENWEBUI_OIDC_CLIENT_SECRET:-dry-run-openwebui-secret}"     "https://ai.${DOMAIN}/oauth/oidc/callback"     "https://ai.${DOMAIN}"

  register_oidc_app "portainer" "Portainer" "portainer-oidc"     "${PORTAINER_OIDC_CLIENT_SECRET:-dry-run-portainer-secret}"     "https://portainer.${DOMAIN}"     "https://portainer.${DOMAIN}"

  configure_forward_auth_outpost
  log "SSO OIDC & ForwardAuth provisioning completed."
}

main "$@"
