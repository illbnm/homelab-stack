<?php
$CONFIG = array (
  'trusted_proxies' => 
  array (
    0 => '172.16.0.0/12',
    1 => '10.0.0.0/8',
    2 => '190.0.0.0/8',
  ),
  'overwriteprotocol' => 'https',
  'default_phone_region' => 'CN',
  'memcache.local' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => 
  array (
    'host' => 'homelab-redis',
    'port' => 6379,
  ),
);
