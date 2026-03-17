#!/bin/bash

NEXTCLOUD_OC_PATH="/var/www/html/occ"

${NEXTCLOUD_OC_PATH} app:enable oauth2
${NEXTCLOUD_OC_PATH} oauth2:add-client --name "Authentik" --redirect-uri "https://nextcloud.example.com/ocs/v2.php/apps/oauth2/api/v1/token" --grant-types "authorization_code" --response-types "code" --scope "openid email profile" --client-id <CLIENT_ID> --client-secret <CLIENT_SECRET>

echo "Nextcloud OIDC setup complete."