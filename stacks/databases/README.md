# 🗄️ Database Layer

> Shared database services for all HomeLab stacks.

## 🎯 Bounty: [#11](../../issues/11) - $130 USDT

## 📋 Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **PostgreSQL** | `postgres:16-alpine` | 5432 | Primary relational database |
| **Redis** | `redis:7-alpine` | 6379 | Cache and message broker |
| **MariaDB** | `mariadb:11.3` | 3306 | MySQL-compatible database |

## 🚀 Quick Start

```bash
cp .env.example .env
docker compose -f stacks/databases/docker-compose.yml up -d
```

## 🌐 Access

All databases are internal-only (not exposed via Traefik).

- PostgreSQL: `postgresql:5432` (internal network)
- Redis: `redis:6379` (internal network)
- MariaDB: `mariadb:3306` (internal network)

---

*Bounty: $130 USDT | Status: In Progress*
