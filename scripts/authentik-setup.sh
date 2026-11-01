#!/usr/bin/env bash
# authentik-setup.sh — Idempotently create OAuth2/OIDC Providers + Applications
# for all homelab services via the Authentik REST API.
#
# Usage:
#   ./scripts/authentik-setup.sh            # apply
#   ./scripts/authentik-setup.sh --dry-run  # preview only
#
# Requires: curl, jq. Env: AUTHENTIK_DOMAIN, AUTHENTIK_BOOTSTRAP_TOKEN, BASE_DOMAIN.
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

: "${AUTHENTIK_DOMAIN:?export AUTHENTIK_DOMAIN (e.g. auth.example.com)}"
: "${AUTHENTIK_BOOTSTRAP_TOKEN:?export AUTHENTIK_BOOTSTRAP_TOKEN}"
: "${BASE_DOMAIN:?export BASE_DOMAIN (e.g. example.com)}"

API="https://${AUTHENTIK_DOMAIN}/api/v3"
AUTH=(-H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"
      -H "Content-Type: application/json")

# Wait until Authentik API is healthy (strict dependency for SSO consumers).
echo "[..] Waiting for Authentik at ${API}/core/health/ ..."
for i in $(seq 1 60); do
  if curl -fsS "${API}/core/health/" >/dev/null 2>&1; then break; fi
  sleep 5
done

api() { # api METHOD PATH [JSON]
  local method="$1" path="$2" body="${3:-}"
  if [[ -n "$body" ]]; then
    curl -fsS -X "$method" "${API}${path}" "${AUTH[@]}" -d "$body"
  else
    curl -fsS -X "$method" "${API}${path}" "${AUTH[@]}"
  fi
}

slug_exists() { # slug_exists providers|applications SLUG -> 0/1
  local kind="$1" slug="$2"
  local q
  if [[ "$kind" == "providers" ]]; then
    q=$(api GET "/providers/oauth2/?slug__iexact=${slug}" | jq '.pagination.count')
  else
    q=$(api GET "/core/applications/?slug=${slug}" | jq '.pagination.count')
  fi
  [[ "$q" -ge 1 ]]
}

ensure_group() { # ensure_group NAME
  local name="$1"
  local count
  count=$(api GET "/core/groups/?name=${name}" | jq '.pagination.count')
  if [[ "$count" -eq 0 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then echo "[DRY] create group: ${name}"; else
      api POST "/core/groups/" "{\"name\":\"${name}\"}" >/dev/null
      echo "[OK] Created group: ${name}"
    fi
  else
    echo "[OK] Group exists: ${name}"
  fi
}

create_provider() { # create_provider NAME SLUG REDIRECT_URI
  local name="$1" slug="$2" redirect="$3"
  if slug_exists providers "$slug"; then
    echo "[OK] Provider exists: ${name} (${slug})"
    return 0
  fi
  local body
  body=$(jq -n --arg name "$name" --arg slug "$slug" --arg redir "$redirect" '{
    name: $name, slug: $slug,
    authorization_flow: null,
    client_type: "confidential",
    sub_mode: "hashed_user_id",
    include_claims_in_id_token: true,
    issuer_mode: "per_provider",
    redirect_uris: [{matching_mode:"strict", url:$redir}],
    signing_key: null,
    property_mappings: []
  }')
  # Resolve default flows dynamically (required by API).
  local auth_flow inval_flow sign_key
  auth_flow=$(api GET "/flows/instances/?designation=authorization&ordering=slug" | jq -r '.results[0].pk')
  inval_flow=$(api GET "/flows/instances/?designation=invalidation&ordering=slug" | jq -r '.results[0].pk')
  sign_key=$(api GET "/crypto/certificatekeypairs/?has_key=true&ordering=name" | jq -r '.results[0].pk')
  body=$(jq --arg af "$auth_flow" --arg if_ "$inval_flow" --arg sk "$sign_key" \
    '.authorization_flow=$af | .invalidation_flow=$if_ | .signing_key=$sk' <<<"$body")
  # Attach the three default OIDC scopes (openid/profile/email).
  local scopes
  scopes=$(api GET "/propertymappings/scope/?ordering=scope_name" \
           | jq '[.results[] | select(.scope_name=="openid" or .scope_name=="profile" or .scope_name=="email") | .pk]')
  body=$(jq --argjson s "$scopes" '.property_mappings=$s' <<<"$body")

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] create provider: ${name} redirect=${redirect}"
    return 0
  fi
  local resp client_id client_secret
  resp=$(api POST "/providers/oauth2/" "$body")
  client_id=$(jq -r '.client_id' <<<"$resp")
  client_secret=$(jq -r '.client_secret' <<<"$resp")
  echo "[OK] Created provider: ${name}"
  echo "      Client ID:     ${client_id}"
  echo "      Client Secret: ${client_secret}"
  echo "      Redirect URI:  ${redirect}"
  # Persist for .env assembly (gitignored directory).
  mkdir -p .secrets
  cat > ".secrets/${slug}.env" <<EOF
${slug^^}_CLIENT_ID=${client_id}
${slug^^}_CLIENT_SECRET=${client_secret}
EOF
}

create_application() { # create_application NAME SLUG PROVIDER_SLUG GROUP
  local name="$1" slug="$2" pslug="$3" group="${4:-}"
  if slug_exists applications "$slug"; then
    echo "[OK] Application exists: ${name}"
    return 0
  fi
  local provider_pk
  provider_pk=$(api GET "/providers/oauth2/?slug__iexact=${pslug}" | jq -r '.results[0].pk')
  local body
  body=$(jq -n --arg name "$name" --arg slug "$slug" --argjson pk "$provider_pk" \
        '{name:$name, slug:$slug, provider:$pk, policy_engine_mode:"any"}')
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] create application: ${name} -> ${pslug}"
  else
    api POST "/core/applications/" "$body" >/dev/null
    echo "[OK] Created application: ${name}"
  fi
  # Bind group policy (restrict who can open the app) when a group is given.
  if [[ -n "$group" ]]; then
    local app_pk group_pk
    app_pk=$(api GET "/core/applications/?slug=${slug}" | jq -r '.results[0].pk')
    group_pk=$(api GET "/core/groups/?name=${group}" | jq -r '.results[0].pk // empty')
    [[ -z "$group_pk" ]] && { echo "[!!] group ${group} not found, skipping binding"; return 0; }
    local policy_pk binding
    policy_pk=$(api POST "/policies/expression/" \
      "$(jq -n --arg n "allow-${group}" --arg g "$group" \
        '{name:$n, expression:("return request.user.ak_groups.filter(name=\"" + $g + "\").exists()")}')" \
      | jq -r '.pk')
    binding=$(jq -n --argjson p "$policy_pk" --argjson t "$app_pk" \
      '{policy:$p, target:$t, order:0, enabled:true}')
    [[ $DRY_RUN -eq 0 ]] && api POST "/policies/bindings/" "$binding" >/dev/null
    echo "[OK] Bound policy: only '${group}' may access ${name}"
  fi
}

# ---- groups ---------------------------------------------------------------
ensure_group homelab-admins
ensure_group homelab-users
ensure_group media-users

# ---- providers + applications --------------------------------------------
# name | slug | redirect-uri | restricting group (empty = any authenticated user)
SERVICES=$(cat <<EOF
Grafana|grafana|https://grafana.${BASE_DOMAIN}/login/generic_oauth|
Gitea|gitea|https://gitea.${BASE_DOMAIN}/user/oauth2/authentik/callback|
Nextcloud|nextcloud|https://nextcloud.${BASE_DOMAIN}/apps/sociallogin/custom_oidc/authentik|
Outline|outline|https://outline.${BASE_DOMAIN}/auth/oidc.callback|
OpenWebUI|openwebui|https://ai.${BASE_DOMAIN}/oauth/oidc/callback|
Portainer|portainer|https://portainer.${BASE_DOMAIN}/|homelab-admins
EOF
)

while IFS='|' read -r name slug redirect group; do
  [[ -z "$name" ]] && continue
  create_provider "$name" "$slug" "$redirect"
  create_application "$name" "$slug" "$slug" "$group"
done <<<"$SERVICES"

echo
echo "Done. Credentials written to ./.secrets/*.env (gitignored)."
echo "Paste each pair into the corresponding stack .env per docs/SSO.md."
