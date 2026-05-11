<?php
// Nextcloud OIDC SSO Configuration for Authentik
$CONFIG = [
    'allow_user_to_change_display_name' => false,
    'lost_password_link' => 'disabled',
    'oidc_login_provider' => 'authentik',
    'oidc_login_client_id' => getenv('NEXTCLOUD_OAUTH_CLIENT_ID'),
    'oidc_login_client_secret' => getenv('NEXTCLOUD_OAUTH_CLIENT_SECRET'),
    'oidc_login_provider_url' => 'https://auth.' . getenv('DOMAIN'),
    'oidc_login_end_session_redirect' => false,
    'oidc_login_auto_redirect' => false,
    'oidc_login_redir_fallback' => false,
    'oidc_login_tls_verify' => true,
    'oidc_login_scope' => 'openid profile email',
    'oidc_login_button_text' => 'Login with Authentik',
    'oidc_login_hide_password_form' => false,
    'oidc_login_use_id_token' => true,
];
