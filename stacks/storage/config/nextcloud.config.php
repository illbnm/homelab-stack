<?php
// Nextcloud custom configuration
// Mounted at /var/www/html/config/custom.config.php

$CONFIG = [
    // Trust reverse proxy headers
    'trusted_proxies' => ['172.16.0.0/12', '10.0.0.0/8', '192.168.0.0/16'],
    'overwriteprotocol' => 'https',
    'overwritecondaddr' => '',
    'forwarded_for_headers' => ['HTTP_X_FORWARDED_FOR', 'HTTP_X_REAL_IP'],

    // Default phone region
    'default_phone_region' => 'CN',

    // Performance optimizations
    'memcache.local' => '\\OC\\Memcache\\APCu',
    'memcache.locking' => '\\OC\\Memcache\\Redis',
    'memcache.distributed' => '\\OC\\Memcache\\Redis',

    // Logging
    'log_type' => 'file',
    'logfile' => '/var/www/html/data/nextcloud.log',
    'loglevel' => 2,  // 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR, 4=FATAL

    // Security
    'token_auth_enforced' => false,
    'auth.bruteforce.protection.enabled' => true,
    'hide_login_form' => false,

    // File handling
    'enable_previews' => true,
    'preview_max_x' => 2048,
    'preview_max_y' => 2048,
    'filesystem_check_changes' => 0,

    // Cron
    'maintenance_window_start' => 1,  // 1 AM UTC

    // Disable update notifications (managed via Watchtower)
    'updatechecker' => false,
    'updater.release.channel' => 'stable',
];
