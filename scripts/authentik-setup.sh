#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack - Authentik SSO setup
#
# Creates the required Authentik groups, OAuth2/OIDC providers, and
# applications for the homelab stack. The script is idempotent and supports a
# dry run that performs no API calls or writes.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_ENV="$ROOT_DIR/.env"
SSO_ENV="$ROOT_DIR/stacks/sso/.env"

DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: scripts/authentik-setup.sh [--dry-run]

Required variables, loaded from root .env and stacks/sso/.env:
  DOMAIN
  AUTHENTIK_DOMAIN
  AUTHENTIK_BOOTSTRAP_TOKEN

The script creates:
  Groups: homelab-admins, homelab-users, media-users
  OAuth2 providers/apps: Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

log() { printf '%s\n' "$*"; }
info() { log "[INFO] $*"; }
warn() { log "[WARN] $*"; }
fail() { log "[ERROR] $*" >&2; exit 1; }

load_env_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

load_env_file "$ROOT_ENV"
load_env_file "$SSO_ENV"

DOMAIN="${DOMAIN:-}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-${DOMAIN:+auth.${DOMAIN}}}"
AUTHENTIK_URL="${AUTHENTIK_URL:-https://${AUTHENTIK_DOMAIN}}"
AUTHENTIK_BOOTSTRAP_TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-${AUTHENTIK_TOKEN:-}}"

[[ -n "$DOMAIN" ]] || fail "DOMAIN is required"
[[ -n "$AUTHENTIK_DOMAIN" ]] || fail "AUTHENTIK_DOMAIN is required"
[[ -n "$AUTHENTIK_BOOTSTRAP_TOKEN" ]] || fail "AUTHENTIK_BOOTSTRAP_TOKEN is required"

API_URL="${AUTHENTIK_URL%/}/api/v3"
AUTH_HEADER="Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

require_tools() {
  local missing=()
  for tool in curl jq; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    fail "Missing required tool(s): ${missing[*]}"
  fi
}

api_get() {
  local path="$1"
  curl -fsS "${API_URL}${path}" \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json"
}

api_post() {
  local path="$1"
  local payload="$2"
  curl -fsS -X POST "${API_URL}${path}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$payload"
}

api_put() {
  local path="$1"
  local payload="$2"
  curl -fsS -X PUT "${API_URL}${path}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$payload"
}

api_patch() {
  local path="$1"
  local payload="$2"
  curl -fsS -X PATCH "${API_URL}${path}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$payload"
}

wait_for_authentik() {
  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run: skipping Authentik readiness check"
    return
  fi

  info "Waiting for Authentik at ${AUTHENTIK_URL}"
  for _ in $(seq 1 60); do
    if curl -fsS "${AUTHENTIK_URL%/}/-/health/ready/" >/dev/null; then
      info "Authentik is ready"
      return
    fi
    sleep 5
  done

  fail "Authentik did not become ready within 300 seconds"
}

wait_for_api_token() {
  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run: skipping Authentik API token check"
    return
  fi

  info "Waiting for Authentik API token access"
  for _ in $(seq 1 60); do
    if api_get "/flows/instances/?designation=authorization&ordering=slug" >/dev/null 2>&1; then
      info "Authentik API token is accepted"
      return
    fi
    sleep 5
  done

  fail "AUTHENTIK_BOOTSTRAP_TOKEN was not accepted by the Authentik API"
}

get_flow_pk() {
  local designation="$1"
  local encoded
  encoded="$(urlencode "$designation")"
  api_get "/flows/instances/?designation=${encoded}&ordering=slug" |
    jq -er '.results[0].pk'
}

get_signing_key_pk() {
  api_get "/crypto/certificatekeypairs/?has_key=true&ordering=name" |
    jq -r '.results[0].pk // empty'
}

find_group_pk() {
  local name="$1"
  local encoded
  encoded="$(urlencode "$name")"
  api_get "/core/groups/?search=${encoded}" |
    jq -r --arg name "$name" '.results[] | select(.name == $name) | .pk' |
    head -n 1
}

ensure_group() {
  local name="$1"

  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run: would ensure group '${name}'"
    return
  fi

  local pk
  pk="$(find_group_pk "$name")"
  if [[ -n "$pk" ]]; then
    info "Group exists: ${name}"
    return
  fi

  local payload
  payload="$(jq -n --arg name "$name" '{name: $name, is_superuser: false, attributes: {}}')"
  api_post "/core/groups/" "$payload" >/dev/null
  info "Created group: ${name}"
}

find_provider_pk() {
  local name="$1"
  local encoded
  encoded="$(urlencode "$name")"
  api_get "/providers/oauth2/?search=${encoded}" |
    jq -r --arg name "$name" '.results[] | select(.name == $name) | .pk' |
    head -n 1
}

find_application_pk() {
  local slug="$1"
  local encoded
  encoded="$(urlencode "$slug")"
  api_get "/core/applications/?search=${encoded}" |
    jq -r --arg slug "$slug" '.results[] | select(.slug == $slug) | .pk' |
    head -n 1
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  [[ -f "$file" ]] || return 0
  local env_value
  env_value="'${value//\'/\'\\\'\'}'"
  local escaped
  escaped="${env_value//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//|/\\|}"
  if grep -qE "^${key}=" "$file"; then
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" "$file"
    rm -f "${file}.bak"
  else
    printf '\n%s=%s\n' "$key" "$env_value" >> "$file"
  fi
}

write_client_credentials() {
  local client_id_var="$1"
  local client_secret_var="$2"
  local client_id="$3"
  local client_secret="$4"

  for env_file in "$ROOT_ENV" "$SSO_ENV"; do
    set_env_value "$env_file" "$client_id_var" "$client_id"
    if [[ -n "$client_secret" && "$client_secret" != *"*"* ]]; then
      set_env_value "$env_file" "$client_secret_var" "$client_secret"
    fi
  done
}

provider_payload() {
  local name="$1"
  local redirect_uri="$2"
  local authorization_flow="$3"
  local invalidation_flow="$4"
  local signing_key="$5"

  jq -n \
    --arg name "$name" \
    --arg redirect_uri "$redirect_uri" \
    --arg authorization_flow "$authorization_flow" \
    --arg invalidation_flow "$invalidation_flow" \
    --arg signing_key "$signing_key" \
    '{
      name: $name,
      authorization_flow: $authorization_flow,
      invalidation_flow: $invalidation_flow,
      client_type: "confidential",
      redirect_uris: $redirect_uri,
      sub_mode: "hashed_user_id",
      issuer_mode: "global",
      include_claims_in_id_token: true
    } + (if $signing_key != "" then {signing_key: $signing_key} else {} end)'
}

ensure_provider_and_application() {
  local slug="$1"
  local display_name="$2"
  local redirect_uri="$3"
  local client_id_var="$4"
  local client_secret_var="$5"
  local launch_url="$6"
  local authorization_flow="$7"
  local invalidation_flow="$8"
  local signing_key="$9"

  local provider_name="${display_name} OAuth2"

  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run: would ensure OAuth2 provider '${provider_name}'"
    info "Dry run: redirect URI ${redirect_uri}"
    info "Dry run: would ensure application '${display_name}' with slug '${slug}'"
    info "Dry run: would write ${client_id_var}/${client_secret_var} to .env files"
    return
  fi

  local payload provider_pk response client_id client_secret app_payload app_pk
  payload="$(provider_payload "$provider_name" "$redirect_uri" "$authorization_flow" "$invalidation_flow" "$signing_key")"
  provider_pk="$(find_provider_pk "$provider_name")"

  if [[ -n "$provider_pk" ]]; then
    response="$(api_patch "/providers/oauth2/${provider_pk}/" "$payload")"
    info "Updated provider: ${provider_name}"
  else
    response="$(api_post "/providers/oauth2/" "$payload")"
    provider_pk="$(printf '%s' "$response" | jq -er '.pk')"
    info "Created provider: ${provider_name}"
  fi

  client_id="$(printf '%s' "$response" | jq -er '.client_id')"
  client_secret="$(printf '%s' "$response" | jq -er '.client_secret')"
  write_client_credentials "$client_id_var" "$client_secret_var" "$client_id" "$client_secret"
  if [[ -n "$client_secret" && "$client_secret" != *"*"* ]]; then
    info "Wrote ${client_id_var}/${client_secret_var} to available .env files"
  else
    warn "Updated ${client_id_var}; Authentik did not return a plaintext ${client_secret_var}"
  fi

  app_payload="$(jq -n \
    --arg name "$display_name" \
    --arg slug "$slug" \
    --arg launch_url "$launch_url" \
    --argjson provider "$provider_pk" \
    '{name: $name, slug: $slug, provider: $provider, meta_launch_url: $launch_url}')"

  app_pk="$(find_application_pk "$slug")"
  if [[ -n "$app_pk" ]]; then
    api_patch "/core/applications/${app_pk}/" "$app_payload" >/dev/null
    info "Updated application: ${display_name}"
  else
    api_post "/core/applications/" "$app_payload" >/dev/null
    info "Created application: ${display_name}"
  fi

  info "OIDC discovery: ${AUTHENTIK_URL%/}/application/o/${slug}/.well-known/openid-configuration"
}

main() {
  info "Authentik URL: ${AUTHENTIK_URL}"
  [[ "$DRY_RUN" == true ]] && info "Dry run enabled: no API calls or file writes will be performed"

  require_tools
  wait_for_authentik
  wait_for_api_token

  local authorization_flow invalidation_flow signing_key
  if [[ "$DRY_RUN" == true ]]; then
    authorization_flow="dry-run-authorization-flow"
    invalidation_flow="dry-run-invalidation-flow"
    signing_key=""
  else
    authorization_flow="$(get_flow_pk authorization)"
    invalidation_flow="$(get_flow_pk invalidation)"
    signing_key="$(get_signing_key_pk)"
  fi

  ensure_group "homelab-admins"
  ensure_group "homelab-users"
  ensure_group "media-users"

  ensure_provider_and_application \
    "grafana" "Grafana" "https://grafana.${DOMAIN}/login/generic_oauth" \
    "GRAFANA_OAUTH_CLIENT_ID" "GRAFANA_OAUTH_CLIENT_SECRET" \
    "https://grafana.${DOMAIN}" "$authorization_flow" "$invalidation_flow" "$signing_key"

  ensure_provider_and_application \
    "gitea" "Gitea" "https://git.${DOMAIN}/user/oauth2/authentik/callback" \
    "GITEA_OAUTH_CLIENT_ID" "GITEA_OAUTH_CLIENT_SECRET" \
    "https://git.${DOMAIN}" "$authorization_flow" "$invalidation_flow" "$signing_key"

  ensure_provider_and_application \
    "nextcloud" "Nextcloud" "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/authentik" \
    "NEXTCLOUD_OAUTH_CLIENT_ID" "NEXTCLOUD_OAUTH_CLIENT_SECRET" \
    "https://nextcloud.${DOMAIN}" "$authorization_flow" "$invalidation_flow" "$signing_key"

  ensure_provider_and_application \
    "outline" "Outline" "https://docs.${DOMAIN}/auth/oidc.callback" \
    "OUTLINE_OAUTH_CLIENT_ID" "OUTLINE_OAUTH_CLIENT_SECRET" \
    "https://docs.${DOMAIN}" "$authorization_flow" "$invalidation_flow" "$signing_key"

  ensure_provider_and_application \
    "open-webui" "Open WebUI" "https://ai.${DOMAIN}/oauth/oidc/callback" \
    "OPENWEBUI_OAUTH_CLIENT_ID" "OPENWEBUI_OAUTH_CLIENT_SECRET" \
    "https://ai.${DOMAIN}" "$authorization_flow" "$invalidation_flow" "$signing_key"

  ensure_provider_and_application \
    "portainer" "Portainer" "https://portainer.${DOMAIN}/" \
    "PORTAINER_OAUTH_CLIENT_ID" "PORTAINER_OAUTH_CLIENT_SECRET" \
    "https://portainer.${DOMAIN}" "$authorization_flow" "$invalidation_flow" "$signing_key"

  info "Authentik SSO setup completed"
}

main "$@"
