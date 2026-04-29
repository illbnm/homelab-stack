# Disaster Recovery — Full Bare-Metal Restore

> Complete procedure to restore HomeLab Stack on a fresh server from backups.

## Prerequisites

- New server with Docker 24+ and Docker Compose v2.20+ installed
- Access to your backup storage (S3/B2/SFTP/local)
- Backup archive from `backup-v2.sh`

## Recovery Order

The recovery order matters because services depend on each other:

```
1. Base Stack (Traefik, Portainer)
   └── Provides: reverse proxy, HTTPS, Docker management

2. Databases Stack (PostgreSQL, Redis, MariaDB)
   └── Provides: shared database layer

3. SSO Stack (Authentik)
   └── Provides: identity provider, OIDC

4. Remaining Stacks
   └── Storage, Media, Network, Productivity, etc.
```

## Step-by-Step Recovery

### Step 1: Prepare the Host

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install dependencies
sudo apt-get install -y apache2-utils curl git

# Create Docker networks
docker network create proxy
docker network create databases

# Clone the repo
git clone https://github.com/YOUR_USERNAME/homelab-stack.git /opt/homelab
cd /opt/homelab
```

### Step 2: Restore Environment

```bash
# Restore .env from backup
# (Assuming you have the backup archive)
tar -xzf /path/to/backup/<timestamp>/configs.tar.gz -C /tmp/restore/
cp /tmp/restore/.env /opt/homelab/.env

# Verify all required variables are set
source .env
echo "DOMAIN=$DOMAIN"
echo "POSTGRES_ROOT_PASSWORD is set: $([ -n "$POSTGRES_ROOT_PASSWORD" ] && echo YES || echo NO)"
```

### Step 3: Start Base Stack

```bash
cd /opt/homelab/stacks/base
ln -sf ../../.env .env
docker compose up -d

# Wait for healthy
sleep 30
docker compose ps
# Verify: traefik=healthy, portainer=healthy, watchtower=healthy
```

### Step 4: Start Databases Stack

```bash
cd /opt/homelab/stacks/databases
ln -sf ../../.env .env
docker compose up -d

# Wait for healthy
sleep 30
docker compose ps
# Verify: postgres=healthy, redis=healthy, mariadb=healthy
```

### Step 5: Restore Database Dumps

```bash
# Find latest backup
LATEST=$(ls -td /opt/homelab-backups/[0-9]* | head -1)

# Restore PostgreSQL
gunzip -c "${LATEST}/postgresql_all.sql.gz" | \
    docker exec -i homelab-postgres psql -U postgres

# Restore MariaDB
gunzip -c "${LATEST}/mariadb_all.sql.gz" | \
    docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}"

# Restore Redis (if available)
if [ -f "${LATEST}/redis_dump.rdb.gz" ]; then
    gunzip -c "${LATEST}/redis_dump.rdb.gz" > /tmp/redis_dump.rdb
    docker cp /tmp/redis_dump.rdb homelab-redis:/data/dump.rdb
    docker restart homelab-redis
fi
```

### Step 6: Start SSO Stack

```bash
cd /opt/homelab/stacks/sso
ln -sf ../../.env .env
docker compose up -d
```

### Step 7: Start Remaining Stacks

```bash
for stack in storage media network productivity backup monitoring dashboard notifications ai home-automation; do
    if [ -f "/opt/homelab/stacks/${stack}/docker-compose.yml" ]; then
        cd "/opt/homelab/stacks/${stack}"
        ln -sf ../../.env .env 2>/dev/null || true
        docker compose up -d
        sleep 10
    fi
done
```

### Step 8: Verify Recovery

```bash
# Check all containers are running + healthy
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v "Exited"

# Check Traefik routing
for service in traefik portainer pgadmin; do
    curl -sf "https://${service}.${DOMAIN}" && echo "OK: ${service}" || echo "FAIL: ${service}"
done

# Check database connectivity
docker exec homelab-postgres psql -U postgres -c '\l'
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

## Estimated Recovery Time (RTO)

| Phase | Time | Notes |
|-------|------|-------|
| Host preparation | 15 min | Docker install, repo clone |
| Base stack | 5 min | Traefik + Portainer |
| Database stack | 5 min | Start containers |
| Database restore | 10-30 min | Depends on data size |
| SSO stack | 5 min | Authentik |
| All other stacks | 20 min | Parallel start |
| Verification | 10 min | Health checks + routing |
| **Total RTO** | **~1-1.5 hours** | |

## Common Recovery Issues

### Traefik certificates are invalid
- Traefik will auto-request new Let's Encrypt certs on first start
- If DNS isn't pointing to the new server yet, update Cloudflare DNS first

### Database users missing
- The initdb script should create users, but if it doesn't run (volume already exists):
  ```bash
  docker exec homelab-postgres psql -U postgres -f /docker-entrypoint-initdb.d/01-init-databases.sh
  ```

### Volume data lost
- If Docker volumes were not backed up, services will start with empty data
- Nextcloud: re-run setup wizard
- Gitea: create admin user + re-push repos
- Vaultwarden: users re-import from Bitwarden export

### SSO (Authentik) lost
- Authentik will need to be re-configured from scratch
- Re-create OAuth2 providers for each service
- Update client IDs/secrets in all stack .env files
