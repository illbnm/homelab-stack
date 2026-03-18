# Live Test Results — Database Stack

Tested: 2026-03-18
Server: DigitalOcean sandbox (137.184.55.8)
Docker: 29.3.0 / Compose v5.1.0

---

## Container Health

All 5 containers running and healthy:

```
NAME                      STATUS
homelab-mariadb           Up About a minute (healthy)
homelab-pgadmin           Up 39 seconds (healthy)
homelab-postgres          Up 4 minutes (healthy)
homelab-redis             Up 4 minutes (healthy)
homelab-redis-commander   Up 14 seconds (healthy)
```

## Test 1: PostgreSQL Databases Created

7 service databases created by init script:

```
    Name     |    Owner    | Encoding
-------------+-------------+----------
 authentik   | authentik   | UTF8
 bookstack   | bookstack   | UTF8
 gitea       | gitea       | UTF8
 grafana     | grafana     | UTF8
 nextcloud   | nextcloud   | UTF8
 outline     | outline     | UTF8
 vaultwarden | vaultwarden | UTF8
```

## Test 2: PostgreSQL User Connectivity

All 7 service users can connect to their databases:

```
  nextcloud: OK
  gitea: OK
  outline: OK
  authentik: OK
  grafana: OK
  vaultwarden: OK
  bookstack: OK
```

## Test 3: Outline uuid-ossp Extension

```
  extname
-----------
 uuid-ossp
```

## Test 4: Redis Connectivity

```
PONG
```

## Test 5: Redis Multi-DB Isolation

Each database is independently addressable:

```
  DB 0: db0_works
  DB 1: db1_works
  DB 2: db2_works
  DB 3: db3_works
  DB 4: db4_works
```

## Test 6: MariaDB Databases

```
Database
bookstack
nextcloud
```

## Test 7: MariaDB User Connectivity

```
BookStack user:  connected = 1
Nextcloud user:  connected = 1
```

## Test 8: Idempotency (PostgreSQL init re-run)

Re-running the init script produces no errors, preserves existing data:

```
[init-postgres] Setting up database: nextcloud
NOTICE:  User already exists (password updated): nextcloud
[init-postgres] Database already exists: nextcloud
[init-postgres] Setting up database: gitea
NOTICE:  User already exists (password updated): gitea
[init-postgres] Database already exists: gitea
[init-postgres] Setting up database: outline
NOTICE:  User already exists (password updated): outline
[init-postgres] Database already exists: outline
NOTICE:  extension "uuid-ossp" already exists, skipping
[init-postgres] Setting up database: authentik
NOTICE:  User already exists (password updated): authentik
[init-postgres] Database already exists: authentik
[init-postgres] Setting up database: grafana
NOTICE:  User already exists (password updated): grafana
[init-postgres] Database already exists: grafana
[init-postgres] Setting up database: vaultwarden
NOTICE:  User already exists (password updated): vaultwarden
[init-postgres] Database already exists: vaultwarden
[init-postgres] Setting up database: bookstack
NOTICE:  User already exists (password updated): bookstack
[init-postgres] Database already exists: bookstack
[init-postgres] All databases initialized successfully
```

Database count after re-run: 7 (unchanged, no data loss)

## Test 9: Network Isolation

No host port bindings on database services:

```
  postgres: (no ports)
  redis: (no ports)
  mariadb: (no ports)
```

Databases accessible only via internal `databases` Docker network.

## Test 10: pgAdmin UI

pgAdmin responds on port 80 (healthy), accessible via Traefik at `pgadmin.${DOMAIN}`. PostgreSQL server auto-registered via `config/pgadmin-servers.json`.

## Test 11: Redis Commander UI

Redis Commander responds on port 8081 (healthy), accessible via Traefik at `redis-ui.${DOMAIN}`. Connected to Redis DB #0.

---

## Summary

| Test | Result |
|------|--------|
| Container health (5/5) | PASS |
| PostgreSQL databases (7/7) | PASS |
| PostgreSQL user connectivity (7/7) | PASS |
| Outline uuid-ossp extension | PASS |
| Redis connectivity | PASS |
| Redis multi-DB isolation (5/5) | PASS |
| MariaDB databases (2/2) | PASS |
| MariaDB user connectivity (2/2) | PASS |
| Idempotency (re-run without errors) | PASS |
| Network isolation (no host ports) | PASS |
| pgAdmin UI | PASS |
| Redis Commander UI | PASS |

**All 12 tests passed.**
