#!/bin/bash

# Nextcloud OIDC Setup Script
# This script sets up Nextcloud with OIDC authentication.

# Variables
NEXTCLOUD_URL="https://nextcloud.example.com"
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"

# Install and configure Nextcloud OIDC app
docker exec -it nextcloud occ app:install user_oidc
docker exec -it nextcloud occ user_oidc:provider:add --name "Authentik" --client-id "$CLIENT_ID" --client-secret "$CLIENT_SECRET" --issuer "$NEXTCLOUD_URL"