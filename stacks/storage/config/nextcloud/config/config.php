<?php
$CONFIG = array (
  'trusted_proxies' => array('traefik'),
  'overwriteprotocol' => 'https',
  'default_phone_region' => 'CN',
  'trusted_domains' => array(
    0 => 'localhost',
    1 => 'cloud.${DOMAIN}',
    2 => '${DOMAIN}',
  ),
  'dbtype' => 'pgsql',
  'dbname' => 'nextcloud',
  'dbhost' => 'postgres:5432',
  'dbuser' => 'nextcloud',
  'dbpassword' => '${NEXTCLOUD_DB_PASSWORD}',
  'dbtableprefix' => 'oc_',
  'redis' => array(
    'host' => 'redis',
    'port' => 6379,
    'password' => '${REDIS_PASSWORD}',
  ),
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  // OIDC 配置 (Authentik)
  'oidc_login' => array(
    'enabled' => true,
    'provider_url' => 'https://sso.${DOMAIN}/application/o/nextcloud/',
    'client_id' => 'nextcloud',
    'client_secret' => '${NEXTCLOUD_OIDC_CLIENT_SECRET}',
    'login_button_text' => 'Authentik SSO',
    'use_with_discovery' => true,
    'redirect_uri' => '/apps/oidc_login/oidc/login',
  ),
  // 防止垃圾注册
  'allow_user_to_change_display_name' => false,
  'lost_password_link' => 'disabled',
  'registration_enabled' => false,
  // 上传限制
  'max_filesize' => '10G',
  'max_input_vars' => 5000,
  'max_input_time' => 3600,
  'max_execution_time' => 3600,
);