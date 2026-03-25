# Disaster Recovery Guide

Complete recovery procedure for homelab-stack from backup.

## Recovery Time Objective (RTO)

- **Full system recovery**: 2-4 hours
- **Single service recovery**: 15-30 minutes
- **Database recovery**: 30-60 minutes

## Recovery Order

Restore services in this order to ensure dependencies:

1. **Base Infrastructure** (Portainer, Watchtower)
2. **Databases** (PostgreSQL, Redis, MariaDB)
3. **SSO/Auth** (Authentik)
4. **Productivity** (Gitea, Outline, etc.)
5. **Media & Other Services**

## Recovery Procedures

### 1. Fresh System Setup

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker

# Clone homelab-stack
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# Restore .env from backup
cp backups/latest/.env .env
```

### 2. Restore Base Infrastructure

```bash
# Start base stack
docker compose -f docker-compose.base.yml up -d

# Verify base services
docker ps
```

### 3. Restore Databases

```bash
# Start database stack
docker compose -f stacks/databases/docker-compose.yml up -d

# Wait for databases to be healthy
docker compose -f stacks/databases/docker-compose.yml ps

# Restore database backups
./scripts/init-databases.sh

# Verify databases
docker exec -it homelab-postgres psql -U postgres -l
docker exec -it homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

### 4. Restore Specific Stack

```bash
# Example: Restore media stack
docker compose -f stacks/media/docker-compose.yml up -d

# Restore volumes from backup
./scripts/backup.sh --restore backup_20240101_020000
```

### 5. Verify Service Health

Check each service after recovery:

- [ ] All containers running: `docker ps -a`
- [ ] All health checks passing: `docker ps --format "{{.Names}}: {{.Status}}"`
- [ ] Web UIs accessible
- [ ] Services can authenticate
- [ ] Data integrity verified

## Volume Recovery Commands

### PostgreSQL
```bash
docker exec -it homelab-postgres pg_restore -U postgres -d dbname < backup.sql
```

### Redis
```bash
docker exec -it homelab-redis redis-cli -a "${REDIS_PASSWORD}" FLUSHALL
```

### Files (generic)
```bash
# Extract backup to volume
docker run --rm \
    -v volume_name:/dest \
    -v /path/to/backup:/backup \
    alpine \
    tar xzf /backup/volume_name.tar.gz -C /dest
```

## Backup Verification Checklist

After any backup, verify:

- [ ] All tar.gz files are valid (not corrupted)
- [ ] Manifest file exists and is complete
- [ ] Remote upload successful (if configured)
- [ ] Backup size is reasonable (not empty, not suspiciously small)

## Common Issues

### Volume Not Found
```bash
# List all volumes
docker volume ls

# Create volume if missing
docker volume create volume_name
```

### Permission Issues
```bash
# Fix permissions
sudo chown -R 1000:1000 ./backups
```

### Database Connection Failed
```bash
# Check if database is running
docker compose -f stacks/databases/docker-compose.yml ps

# Check logs
docker compose -f stacks/databases/docker-compose.yml logs postgres
```

## Automated Restore Testing

Periodically test restore procedure in a VM:

```bash
# Create test environment
git clone https://github.com/illbnm/homelab-stack.git test-homelab
cd test-homelab

# Run restore procedure
# ... (follow recovery steps above)

# Verify all services work
./scripts/test-stacks.sh
```

## Important Notes

1. **Always verify backups** before attempting restore
2. **Test restore procedure** periodically on non-production system
3. **Keep backup credentials secure** - they grant access to all data
4. **Monitor backup jobs** - set up ntfy notifications for failures
5. **Document any custom configurations** - they won't be in backups

## Emergency Contacts

If recovery fails:
1. Check logs: `docker compose logs -f <service>`
2. Verify network: `docker network ls`
3. Check disk space: `df -h`
4. Review recent changes before failure
