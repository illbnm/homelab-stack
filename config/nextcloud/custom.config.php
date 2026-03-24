<?php
/**
 * Nextcloud custom configuration for HomeLab Stack
 *
 * This file is mounted into the Nextcloud container and provides:
 *   - Trusted proxy settings for Traefik
 *   - Protocol overwrite for HTTPS behind reverse proxy
 *   - Default phone region
 *   - Authentik OIDC integration (requires 'user_oidc' app)
 *
 * Place at: config/nextcloud/custom.config.php
 */

// Trusted proxies — adjust to match your Docker network / Traefik CIDR
$CONFIG = [
    'trusted_proxies'   => ['172.16.0.0/12', '10.0.0.0/8', '192.168.0.0/16'],
    'overwriteprotocol' => 'https',
    'default_phone_region' => 'CN',

    // Redis (shared homelab-redis)
    'memcache.local'    => '\\OC\\Memcache\\Redis',
    'memcache.locking'  => '\\OC\\Memcache\\Redis',
    'memcache.distributed' => '\\OC\\Memcache\\Redis',

    // OIDC via Authentik — uncomment and configure after installing user_oidc app
    // 'oidc_login_provider_url' => 'https://auth.${DOMAIN}/application/o/nextcloud/',
    // 'oidc_login_client_id'    => 'nextcloud',
    // 'oidc_login_client_secret' => '${OIDC_CLIENT_SECRET}',
    // 'oidc_login_auto_redirect' => true,
    // 'oidc_login_hide_password_form' => true,
    // 'oidc_login_attributes' => [
    //     'id'       => 'preferred_username',
    //     'name'     => 'name',
    //     'mail'     => 'email',
    //     'groups'   => 'groups',
    // ],
    // 'oidc_login_default_group' => 'users',
    // 'oidc_login_logout_url' => 'https://auth.${DOMAIN}/application/o/nextcloud/end-session/',
];
