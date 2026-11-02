#!/usr/bin/env bash
# authentik-setup.sh — automate OAuth2/OIDC provider creation for the homelab stack.
#
# Creates one OAuth2/OIDC Provider + Application per integrated service via the
# Authentik API, and prints the Client ID / Client Secret / redirect URI each
# service needs. Idempotent: existing providers/apps are reused, not duplicated.
#
# Usage:
#   ./scripts/authentik-setup.sh [--dry-run] [--base-url URL] [--token T] [--domain D]
#
# Env (fallbacks): AUTHENTIK_URL, AUTHENTIK_TOKEN, DOMAIN
#
# Exit codes: 0 ok, 1 error, 2 usage
set -euo pipefail

DRY_RUN=0
BASE_URL="${AUTHENTIK_URL:-https://auth.${DOMAIN:-example.com}}"
TOKEN="${AUTHENTIK_TOKEN:-}"
DOMAIN="${DOMAIN:-example.com}"

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '1,20p'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --base-url) BASE_URL="$2"; shift 2 ;;
    --token)    TOKEN="$2"; shift 2 ;;
    --domain)   DOMAIN="$2"; sed -i "s#https://auth\.*[^/]*#https://auth.${DOMAIN}#" /dev/null 2>/dev/null || true; shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "unknown arg: $1" >&2; usage 2 ;;
  esac
done

# Refresh base url if DOMAIN changed after the fact
BASE_URL="${BASE_URL/example.com/$DOMAIN}"

log()  { printf '%b\n' "$*"; }
ok()   { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*" >&2; }
die()  { printf '  [ERR] %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"
command -v jq   >/dev/null || die "jq is required"

if [[ $DRY_RUN -eq 0 && -z "$TOKEN" ]]; then
  die "no AUTHENTIK_TOKEN provided (use --token or env). Use --dry-run to preview."
fi

API="${BASE_URL%/}/api/v3"

# api METHOD PATH [JSON_BODY] -> prints response body, fails on HTTP >=400
api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" "${API}${path}"
              -H "Authorization: Bearer ${TOKEN}"
              -H "Accept: application/json")
  [[ -n "$body" ]] && args+=(-H "Content-Type: application/json" -d "$body")
  if [[ $DRY_RUN -eq 1 ]]; then
    log "    [dry-run] $method ${path} ${body:+<json>}" >&2
    echo '{"dry_run":true}'
    return 0
  fi
  local out code
  out="$(curl "${args[@]}" -w $'\n%{http_code}' || true)"
  code="$(tail -n1 <<<"$out")"
  out="$(sed '$d' <<<"$out")"
  if [[ "$code" -ge 400 ]]; then
    die "API $method $path -> HTTP $code: ${out:0:200}"
  fi
  printf '%s' "$out"
}

# --- service definitions: name|slug|redirect_path|scopes ---
# Redirect URIs are built from DOMAIN. Adjust per service callback convention.
SERVICES=(
  "Grafana|grafana|/login/generic_oauth|openid profile email"
  "Gitea|gitea|/user/oauth2/authentik/callback|openid profile email"
  "Nextcloud|nextcloud|/apps/user_oidc/code|openid profile email"
  "Outline|outline|/auth/oidc.callback|openid profile email"
  "Open WebUI|open-webui|/oauth/oidc/callback|openid profile email"
  "Portainer|portainer|/|openid profile email"
)

# host-name mapping used to compute the redirect base
svc_host() {
  case "$1" in
    grafana)    echo "grafana.${DOMAIN}" ;;
    gitea)      echo "gitea.${DOMAIN}" ;;
    nextcloud)  echo "nextcloud.${DOMAIN}" ;;
    outline)    echo "outline.${DOMAIN}" ;;
    open-webui) echo "chat.${DOMAIN}" ;;
    portainer)  echo "portainer.${DOMAIN}" ;;
    *)          echo "$1.${DOMAIN}" ;;
  esac
}

# get-or-create authorization flow (default provider flow)
get_flow() {
  # "default-provider-authorization-explicit-consent" or implicit
  api GET "/flows/instances/?slug=default-provider-authorization-explicit-consent" \
    | jq -r '.results[0].pk // empty'
}

get_signing_key() {
  api GET "/crypto/certificatekeypairs/?ordering=name" \
    | jq -r '.results[] | select(.name=="authentik Self-signed Certificate") | .pk' \
    | head -n1
}

log "== Authentik SSO setup (domain=${DOMAIN}, api=${API}, dry_run=${DRY_RUN}) =="

if [[ $DRY_RUN -eq 1 ]]; then
  AUTHZ_FLOW="dry-flow-pk"
  SIGNING_KEY="dry-signing-key"
else
  AUTHZ_FLOW="$(get_flow)"
  [[ -z "$AUTHZ_FLOW" || "$AUTHZ_FLOW" == "null" ]] && \
    AUTHZ_FLOW="$(api GET "/flows/instances/?ordering=slug" | jq -r '.results[0].pk // empty')"
  [[ -z "$AUTHZ_FLOW" ]] && die "no authorization flow found; create one in Authentik UI first"
  SIGNING_KEY="$(get_signing_key)"
fi

log "authorization_flow=${AUTHZ_FLOW} signing_key=${SIGNING_KEY:-<none>}"

# output collection for the summary table
declare -a SUMMARY=()

for def in "${SERVICES[@]}"; do
  IFS='|' read -r NAME SLUG RPATH SCOPES <<<"$def"
  HOST="$(svc_host "$SLUG")"
  REDIRECT="https://${HOST}${RPATH}"

  log ""
  log "[..] ${NAME}"

  # find existing provider by name
  EXISTING_PK="$(api GET "/providers/oauth2-oauth/?search=${SLUG}" \
     | jq -r --arg n "$NAME" '(.results // [])[] | select(.name==$n) | .pk' | head -n1 || true)"

  REDIRECT_JSON="$(printf '%s' "$REDIRECT" | jq -R .)"
  SCOPES_JSON="$(printf '%s' "$SCOPES" | jq -R 'split(" ")')"

  if [[ -n "$EXISTING_PK" && "$EXISTING_PK" != "null" ]]; then
    ok "provider exists, pk=${EXISTING_PK}"
    PROVIDER_PK="$EXISTING_PK"
  else
    BODY="$(jq -n \
      --arg name "$NAME" \
      --arg client_id "$SLUG" \
      --arg authz "$AUTHZ_FLOW" \
      --argjson redirect "$REDIRECT_JSON" \
      --argjson scopes "$SCOPES_JSON" \
      --arg key "$SIGNING_KEY" \
      '{name:$name, authorization_flow:$authz,
        client_type:"confidential", client_id:$client_id,
        redirect_uris:[{matching_mode:"strict", url:$redirect}],
        property_mappings:[], sub_mode:"hashed_user_id",
        include_claims_in_id_token:true, signing_key:$key,
        access_code_validity:"minutes=1", access_token_validity:"minutes=5",
        refresh_token_validity:"days=30"} | del(.signing_key | select(. == ""))'
    )"
    if [[ $DRY_RUN -eq 1 ]]; then
      ok "would create provider ${NAME} redirect=${REDIRECT}"
      PROVIDER_PK="dry"
    else
      RESP="$(api POST "/providers/oauth2-oauth/" "$BODY")"
      PROVIDER_PK="$(jq -r '.pk' <<<"$RESP")"
      ok "created provider pk=${PROVIDER_PK}"
    fi
  fi

  # Application
  APP_EXIST="$(api GET "/core/applications/?slug=${SLUG}" \
      | jq -r '(.results // [])[0].slug // empty' || true)"
  if [[ -n "$APP_EXIST" && "$APP_EXIST" != "null" ]]; then
    ok "application exists (slug=${SLUG})"
  else
    APP_BODY="$(jq -n --arg name "$NAME" --arg slug "$SLUG" \
      --arg provider "$PROVIDER_PK" \
      '{name:$name, slug:$slug, provider:$provider,
        meta_launch_url:"", policy_engine_mode:"any"}')"
    if [[ $DRY_RUN -eq 1 ]]; then
      ok "would create application ${SLUG}"
    else
      api POST "/core/applications/" "$APP_BODY" >/dev/null
      ok "created application ${SLUG}"
    fi
  fi

  # fetch client id/secret for summary
  if [[ $DRY_RUN -eq 0 && "$PROVIDER_PK" != "dry" ]]; then
    DETAIL="$(api GET "/providers/oauth2-oauth/${PROVIDER_PK}/")"
    CID="$(jq -r '.client_id' <<<"$DETAIL")"
    CSEC="$(jq -r '.client_secret' <<<"$DETAIL")"
  else
    CID="$SLUG"; CSEC="<dry-run>"
  fi
  SUMMARY+=("${NAME}|${CID}|${CSEC}|${REDIRECT}")
done

log ""
log "================ SUMMARY ================"
printf '%-14s %-20s %s\n' "SERVICE" "CLIENT_ID" "REDIRECT_URI"
for row in "${SUMMARY[@]}"; do
  IFS='|' read -r n c s r <<<"$row"
  printf '%-14s %-20s %s\n' "$n" "$c" "$r"
done
log "========================================"
log ""
log "Fill each CLIENT_ID / CLIENT_SECRET into the service's .env or config."
log "Secrets are only fully shown with a fresh provider; fetch via API if needed:"
log "  GET ${API}/providers/oauth2-oauth/<pk>/  (client_secret)"
exit 0
