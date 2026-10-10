#!/bin/sh
# Run inside the healthy Gitea container as the git user, once per installation.
set -eu
: "${GITEA_OAUTH_CLIENT_ID:?Set GITEA_OAUTH_CLIENT_ID}"
: "${GITEA_OAUTH_CLIENT_SECRET:?Set GITEA_OAUTH_CLIENT_SECRET}"
: "${AUTHENTIK_DOMAIN:?Set AUTHENTIK_DOMAIN}"
exec gitea admin auth add-oauth --config /data/gitea/conf/app.ini \
  --name Authentik --provider openidConnect \
  --key "$GITEA_OAUTH_CLIENT_ID" --secret "$GITEA_OAUTH_CLIENT_SECRET" \
  --auto-discover-url "https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration" \
  --scopes profile --scopes email
