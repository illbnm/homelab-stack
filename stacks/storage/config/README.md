# Nextcloud Configuration

This directory contains your local Nextcloud configuration.

On first startup, Nextcloud will generate the basic `config.php`, you need to add the following configurations at the end before the closing `);`:

```php
// Trusted proxy configuration for Traefik
$CONFIG['trusted_proxies'] = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'];
$CONFIG['overwriteprotocol'] = 'https';
$CONFIG['default_phone_region'] = 'CN'; // Change to your country code

// Redis cache configuration
$CONFIG['memcache.local'] = '\\OC\\Memcache\\Redis';
$CONFIG['memcache.distributed'] = '\\OC\\Memcache\\Redis';
$CONFIG['memcache.locking'] = '\\OC\\Memcache\\Redis';
$CONFIG['redis_host'] = getenv('REDIS_HOST');
$CONFIG['redis_port'] = 6379;
$CONFIG['redis_password'] = getenv('REDIS_HOST_PASSWORD');

// Authentik OIDC SSO - uncomment and configure after setup
// $CONFIG['user_oidc_providers'] = [
//     [
//         'identifier' => 'authentik',
//         'clientId' => 'nextcloud',
//         'clientSecret' => 'your-client-secret',
//         'discoveryUrl' => 'https://authentik.yourdomain.com/application/o/nextcloud/.well-known/openid-configuration',
//         'scope' => 'openid email profile',
//         'isEndpointEnabled' => true,
//         'usePkce' => false,
//         'attributes' => [
//             'uid' => 'preferred_username',
//             'displayName' => 'name',
//             'email' => 'email',
//         ],
//         'buttonText' => 'Log in with Authentik',
//         'buttonImage' => '',
//     ],
// ];
```

## First Run Notes

1. After starting the stack, Nextcloud will automatically install via the web installer
2. Make sure you have the databases stack running with PostgreSQL and Redis already created
3. Update the `default_phone_region` to your 2-letter ISO country code
4. Configure Authentik OIDC according to the [authentik documentation](https://docs.goauthentik.io/docs/providers/oauth2/overview)
