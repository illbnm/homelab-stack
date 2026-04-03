<?php
/**
 * Nextcloud OIDC / Social Login Configuration
 * Used by the "OpenID Connect Login" app.
 *
 * Install the app first: docker exec nextcloud occ app:install oidc_login
 * Mount this file: ./nextcloud-oidc.config.php:/var/www/html/config/oidc.config.php:ro
 *
 * Docs: https://apps.nextcloud.com/apps/oidc_login
 */

$host = getenv('AUTHENTIK_DOMAIN') ?: ('auth.' . getenv('DOMAIN'));

$CONFIG = [
    // Enable OIDC login as an additional option (not replacing password login)
    'oidc_login_multiple_accounts' => true,
    'oidc_login_auto_redirect' => false,
    'oidc_login_default_group' => 'users',

    // Authentik OIDC provider settings
    'oidc_login_provider_url' => 'https://' . $host . '/application/o/nextcloud/',

    // OAuth client credentials (from .env)
    'oidc_login_client_id'      => getenv('NEXTCLOUD_OAUTH_CLIENT_ID') ?: '',
    'oidc_login_client_secret'  => getenv('NEXTCLOUD_OAUTH_CLIENT_SECRET') ?: '',

    // OIDC scopes
    'oidc_login_scope' => 'openid profile email groups',

    // Attribute mapping
    'oidc_login_attributes' => [
        'identifier' => 'preferred_username',
        'name'       => 'name',
        'email'      => 'email',
    ],

    // Allow new user creation on first login
    'oidc_login_create_accounts' => true,

    // Use the OIDC provider display name as Nextcloud display name
    'oidc_login_use_idp_given_name' => false,

    // Logout from Nextcloud also logs out from Authentik
    'oidc_login_logout_url' => 'https://' . $host . '/application/o/nextcloud/end-session/',
];
