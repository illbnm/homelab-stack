<?php
$CONFIG = array(
  'trusted_proxies' => array('172.16.0.0/12', '192.168.0.0/16', '10.0.0.0/8'),
  'overwriteprotocol' => 'https',
  'default_phone_region' => 'CN',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => array(
    'host' => getenv('REDIS_HOST') ?: 'redis',
    'port' => 6379,
    'dbindex' => 3,
  ),
  'allow_local_remote_servers' => true,
);
