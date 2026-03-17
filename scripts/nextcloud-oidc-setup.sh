#!/bin/bash

NEXTCLOUD_OC_PATH="/var/www/html/occ"
CLIENT_ID=<CLIENT_ID>
CLIENT_SECRET=<CLIENT_SECRET>

$NEXTCLOUD_OC_PATH app:enable oauth2
$NEXTCLOUD_OC_PATH oauth2:add-client --name="Authentik" --redirect-uri="https://nextcloud.example.com/nextcloud/index.php/apps/oauth2/authorize" --grant-types="authorization_code" --response-types="code" --scope="openid profile email" --client-id="$CLIENT_ID" --client-secret="$CLIENT_SECRET"
echo "Nextcloud OIDC setup complete."