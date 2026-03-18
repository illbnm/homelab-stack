# Database Layer — Deployment Test Results

**Date:** 2026-03-17
**Sandbox:** root@137.184.55.8
**Stack:** databases (PostgreSQL + Redis + MariaDB + pgAdmin + Redis Commander)

## Container Health — ALL PASS ✅

| Container | Image | Status |
|-----------|-------|--------|
| homelab-postgres | postgres:16.4-alpine | Up (healthy) |
| homelab-redis | redis:7.4.0-alpine | Up (healthy) |
| homelab-mariadb | mariadb:11.5.2 | Up (healthy) |
| homelab-pgadmin | dpage/pgadmin4:8.11 | Up (healthy) |
| homelab-redis-commander | rediscommander/redis-commander:latest | Up (healthy) |

## Test Results

### 1. PostgreSQL: 7 Databases Created ✅
```
authentik, bookstack, gitea, grafana, nextcloud, outline, vaultwarden
```

### 2. PostgreSQL: 7 Users Created ✅
```
authentik, bookstack, gitea, grafana, nextcloud, outline, vaultwarden
```

### 3. PostgreSQL: uuid-ossp Extension on Outline ✅
```
SELECT extname FROM pg_extension WHERE extname='uuid-ossp';
→ uuid-ossp
```

### 4. PostgreSQL: Service User Authentication ✅
```
nextcloud → nextcloud (auth OK)
grafana   → grafana   (auth OK)
vaultwarden → vaultwarden (auth OK)
```

### 5. PostgreSQL: Idempotency Re-run ✅
Re-ran init script on running database. All 7 databases reported "already exists" with password updates. No errors. Exit code 0.
```
[init-postgres] Setting up database: nextcloud
NOTICE:  User already exists (password updated): nextcloud
[init-postgres] Database already exists: nextcloud
... (repeated for all 7 databases)
[init-postgres] All databases initialized successfully
```

### 6. Redis: Ping + 16 Databases ✅
```
PING → PONG
databases → 16
```

### 7. Redis: Cross-DB Isolation ✅
```
DB0: SET test_key "authentik_ok" → OK
DB4: SET test_key "grafana_ok"   → OK
DB0: GET test_key → "authentik_ok"  (isolated from DB4)
DB4: GET test_key → "grafana_ok"   (isolated from DB0)
```

### 8. MariaDB: 2 Databases Created ✅
```
bookstack, nextcloud
```

### 9. MariaDB: User Authentication ✅
```
bookstack → bookstack@localhost (auth OK)
nextcloud → nextcloud@localhost (auth OK)
```

### 10. MariaDB: utf8mb4 Charset ✅
```
bookstack → utf8mb4
nextcloud → utf8mb4
```

### 11. Network Isolation ✅
```
databases network: homelab-postgres, homelab-redis, homelab-mariadb, homelab-pgadmin, homelab-redis-commander
proxy network:     homelab-pgadmin, homelab-redis-commander (only admin UIs)
```
Database services are NOT on the proxy network — correct isolation.

### 12. pgAdmin Health ✅
```
Status: healthy
Responds on /misc/ping
Pre-configured with HomeLab PostgreSQL server via pgadmin-servers.json
```

### 13. Redis Commander Health ✅
```
Status: healthy
HTTP 200 on port 8081
Connected to Redis DB #0 at homelab-redis:6379
```

## Issues Found & Fixed During Testing

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| MariaDB init didn't run | MariaDB 11.5.2 removed `mysql` binary symlink | Changed to `mariadb` binary |
| Backup script would fail | `mysqldump` also removed in MariaDB 11.5+ | Changed to `mariadb-dump` |
| pgAdmin crash loop | `.local` TLD rejected as email domain | Use proper email format in .env |
| Redis Commander unhealthy | `/favicon.png` endpoint doesn't exist | Changed healthcheck to `/` |

## Summary

**14/14 tests PASS** — all services operational, init scripts idempotent, network isolation correct, admin UIs healthy.
