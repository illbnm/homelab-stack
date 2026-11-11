# Shared Databases Stack — PostgreSQL + Redis + MariaDB + pgAdmin + Redis Commander

## Internal Connection Strings & Redis DB Allocation

| Consumer Service | PostgreSQL URI (`internal` network) | Redis URI (`internal` network) |
|---|---|---|
| Authentik | `postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik` | `redis://:${REDIS_PASSWORD}@redis:6379/0` |
| Outline | `postgres://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline` | `redis://:${REDIS_PASSWORD}@redis:6379/1` |
| Gitea | `postgres://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea` | `redis://:${REDIS_PASSWORD}@redis:6379/2` |
| Nextcloud | `postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud` | `redis://:${REDIS_PASSWORD}@redis:6379/3` |
| Grafana | `postgres://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana` | `redis://:${REDIS_PASSWORD}@redis:6379/4` |
