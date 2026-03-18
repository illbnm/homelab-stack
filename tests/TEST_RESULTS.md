# Integration Testing — Test Results

## Test Run: 2026-03-18

### Environment
- **Server:** DigitalOcean Droplet (Ubuntu 22.04, 4GB RAM)
- **Docker:** Docker Engine 27.x + Compose v2
- **Stacks tested:** databases, storage (base stack not deployed during this run)

### Results Summary
```
58 passed, 0 failed, 0 skipped — Duration: 6s
```

### Databases Stack (32 tests)
```
[databases] ▶ compose syntax                 ✅ PASS
[databases] ▶ mariadb bookstack db           ✅ PASS
[databases] ▶ mariadb healthy                ✅ PASS
[databases] ▶ mariadb not on proxy           ✅ PASS
[databases] ▶ mariadb running                ✅ PASS
[databases] ▶ network exists                 ✅ PASS
[databases] ▶ no latest tags                 ✅ PASS
[databases] ▶ pg accepts connections         ✅ PASS
[databases] ▶ pg authentik db                ✅ PASS
[databases] ▶ pg bookstack db                ✅ PASS
[databases] ▶ pg gitea db                    ✅ PASS
[databases] ▶ pg grafana db                  ✅ PASS
[databases] ▶ pg nextcloud db                ✅ PASS
[databases] ▶ pg outline db                  ✅ PASS
[databases] ▶ pg uuid ossp                   ✅ PASS
[databases] ▶ pg vaultwarden db              ✅ PASS
[databases] ▶ pgadmin healthy                ✅ PASS
[databases] ▶ pgadmin http                   ✅ PASS
[databases] ▶ pgadmin on proxy               ✅ PASS
[databases] ▶ pgadmin running                ✅ PASS
[databases] ▶ postgres healthy               ✅ PASS
[databases] ▶ postgres not on proxy          ✅ PASS
[databases] ▶ postgres running               ✅ PASS
[databases] ▶ redis commander healthy        ✅ PASS
[databases] ▶ redis commander http           ✅ PASS
[databases] ▶ redis commander on proxy       ✅ PASS
[databases] ▶ redis commander running        ✅ PASS
[databases] ▶ redis healthy                  ✅ PASS
[databases] ▶ redis multi db                 ✅ PASS
[databases] ▶ redis not on proxy             ✅ PASS
[databases] ▶ redis ping                     ✅ PASS
[databases] ▶ redis running                  ✅ PASS
```

### Storage Stack (26 tests)
```
[storage] ▶ compose syntax                 ✅ PASS
[storage] ▶ filebrowser healthy            ✅ PASS
[storage] ▶ filebrowser http               ✅ PASS
[storage] ▶ filebrowser running            ✅ PASS
[storage] ▶ internal network exists        ✅ PASS
[storage] ▶ minio buckets exist            ✅ PASS
[storage] ▶ minio console                  ✅ PASS
[storage] ▶ minio health                   ✅ PASS
[storage] ▶ minio healthy                  ✅ PASS
[storage] ▶ minio init completed           ✅ PASS
[storage] ▶ minio running                  ✅ PASS
[storage] ▶ nextcloud cron running         ✅ PASS
[storage] ▶ nextcloud fpm not on proxy     ✅ PASS
[storage] ▶ nextcloud healthy              ✅ PASS
[storage] ▶ nextcloud installed            ✅ PASS
[storage] ▶ nextcloud nginx healthy        ✅ PASS
[storage] ▶ nextcloud nginx on proxy       ✅ PASS
[storage] ▶ nextcloud nginx running        ✅ PASS
[storage] ▶ nextcloud pg connection        ✅ PASS
[storage] ▶ nextcloud running              ✅ PASS
[storage] ▶ nextcloud version              ✅ PASS
[storage] ▶ no latest tags                 ✅ PASS
[storage] ▶ syncthing api                  ✅ PASS
[storage] ▶ syncthing healthy              ✅ PASS
[storage] ▶ syncthing p2p port             ✅ PASS
[storage] ▶ syncthing running              ✅ PASS
```

### Test Coverage by Level
| Level | Description | Tests |
|-------|-------------|-------|
| Level 1 | Container health + configuration | 24 |
| Level 2 | HTTP endpoints + service functionality | 28 |
| Level 3 | Network isolation + integration | 6 |

### ShellCheck
All test files pass ShellCheck with zero warnings/errors (only SC1091 info about sourced files and SC2016 info about intentional single quotes in default messages).
