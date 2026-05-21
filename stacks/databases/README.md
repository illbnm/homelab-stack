# 🗄️ Shared Database Stack

A centralized database layer for the HomeLab Stack, providing PostgreSQL, Redis, and MariaDB instances. By keeping databases in a single stack, we minimize memory overhead and simplify backups.

## 📦 Included Services

- **PostgreSQL (16-alpine)**: Relational database used by Nextcloud, Authentik, Outline, Vaultwarden, etc.
- **MariaDB (11.4)**: MySQL-compatible database used by BookStack and older services.
- **Redis (7-alpine)**: In-memory cache used for session storage, caching, and task queues (Authentik, Nextcloud).

## 🚀 Getting Started

1. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env and set strong, secure passwords for ROOT users and service-specific users.
   nano .env
   ```

2. **Database Initialization Scripts**
   - **PostgreSQL**: Place `.sql` or `.sh` scripts in `initdb/`. These will run automatically the first time the database is initialized. A default `01-create-dbs.sh` is provided to create databases and users for all core services based on your `.env` passwords.
   - **MariaDB**: Place `.sql` or `.sh` scripts in `initdb-mysql/`. A default `01-create-dbs.sql` is provided.

3. **Start the Stack**
   ```bash
   docker compose up -d
   ```

## 🔌 Connecting from other Stacks

This stack creates a Docker network named `databases`. For other containers to connect to these databases, they must join the `databases` network as an external network.

Example in another stack's `docker-compose.yml`:
```yaml
services:
  nextcloud:
    # ...
    networks:
      - proxy
      - databases

networks:
  proxy:
    external: true
  databases:
    external: true
```

Hostnames to use:
- PostgreSQL: `homelab-postgres`
- MariaDB: `homelab-mariadb`
- Redis: `homelab-redis`

## 🛠️ Troubleshooting

- **Containers failing health checks**: Check the logs using `docker compose logs -f postgres`. Ensure passwords in `.env` do not contain special characters that might break bash scripts unless properly quoted.
- **Cannot connect to database**: Ensure your service is attached to the `databases` network and using the correct hostname (`homelab-postgres`, `homelab-mariadb`, `homelab-redis`).
- **Data persistence**: Data is stored in Docker volumes (`postgres-data`, `mariadb-data`, `redis-data`). To wipe the database and start fresh, run `docker compose down -v`.
