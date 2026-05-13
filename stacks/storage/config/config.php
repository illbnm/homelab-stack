<?php
$CONFIG = array (
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'pgsql',
  'dbname' => 'nextcloud',
  'dbhost' => 'homelab-postgres:5432',
  'dbuser' => 'nextcloud',
  'dbpassword' => getenv('POSTGRES_PASSWORD') ?: 'changeme',
  'dbport' => 5432,

  'trusted_domains' => array (
    0 => 'localhost',
    1 => getenv('NEXTCLOUD_DOMAIN') ?: getenv('DOMAIN') ? 'cloud.' . getenv('DOMAIN') : 'localhost',
  ),
  'trusted_proxies' => array (
    'traefik',
    '172.16.0.0/12',
  ),
  'overwriteprotocol' => 'https',
  'overwritecondaddr' => '^172\\.16\\..*$',

  'default_phone_region' => 'CN',

  'memcache.local' => '\\OC\\Memcache\\Redis',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => array (
    'host' => 'homelab-redis',
    'port' => 6379,
    'password' => getenv('REDIS_PASSWORD') ?: 'changeme',
  ),

  'forcessl' => true,
  'default_locale' => 'zh_CN',
  'default_language' => 'zh_CN',

  'maintenance' => false,
  'loglevel' => 2,
  'logtype' => 'file',
  'logfile' => '/var/www/html/data/nextcloud.log',
  'logtimezone' => getenv('TZ') ?: 'Asia/Shanghai',

  'apps_paths' => array (
    0 => array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),

  'one_click_upgrade' => true,
  'upgrade.disable-web' => true,
);
