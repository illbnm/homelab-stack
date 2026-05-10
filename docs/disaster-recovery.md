# Disaster Recovery — HomeLab Stack

Complete recovery guide for restoring all services from backups on a fresh host.

## Recovery Time Objective (RTO)

| Scenario | Estimated Time |
|----------|---------------|
| Single service failure | 10-30 minutes |
| Database corruption | 30-60 minutes |
| Full host failure (fresh install) | 2-4 hours |
| Off-site restore (from cloud) | 4-8 hours (depends on bandwidth) |

## Recovery Point Objective (RPO)

- Database backups: daily (last 24h max data loss)
- Config backups: daily
- Volume backups: daily
- Cloud sync: after each local backup

## Prerequisites for Recovery

- New host with Docker + Docker Compose installed
- `mc` client (for MinIO backups)
- `restic` (for Restic repository)
- Backup files accessible (local disk, S3, B2, or R2)

## Full Recovery Process

### Step 1: Prepare Host

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Install Docker Compose
apt install -y docker-compose-plugin

# Clone the repo
git clone https://github.com/YOUR_USERNAME/homelab-stack.git /opt/homelab-stack
cd /opt/homelab-stack
```

### Step 2: Restore Configuration

```bash
# Find latest backup
BACKUP_ID=$(ls -1 /opt/homelab-backups/ | sort | tail -1)

# Restore configs
tar xzf /opt/homelab-backups/$BACKUP_ID/configs.tar.gz -C /opt/homelab-stack/

# Restore .env
cp config/.env.example .env
# Edit .env with your restored credentials
# (Check the restored configs for original values)
```

### Step 3: Start Core Infrastructure

```bash
# Create required networks
docker network create proxy
docker network create databases
docker network create backup

# Start in dependency order:
# 1. Databases (required by everything)
cd stacks/databases && docker compose up -d
sleep 30  # Wait for PostgreSQL

# 2. Restore database dumps
docker exec -i homelab-postgres psql -U postgres < /opt/homelab-backups/$BACKUP_ID/postgresql_all.sql

# 3. SSO (required by authenticated services)
cd ../sso && docker compose up -d
sleep 60  # Wait for Authentik initialization

# 4. Base infrastructure (Traefik + Portainer)
cd ../base && docker compose up -d

# 5. Remaining stacks in parallel
for stack in notifications monitoring storage media productivity network ai home-automation; do
  cd ../$stack && docker compose up -d 2>/dev/null || true
done
```

### Step 4: Restore Volumes

```bash
BACKUP_ID=$(ls -1 /opt/homelab-backups/ | sort | tail -1)
for vol_tar in /opt/homelab-backups/$BACKUP_ID/vol_*.tar.gz; do
  VOL_NAME=$(basename "$vol_tar" .tar.gz | sed 's/^vol_//')
  docker volume create "$VOL_NAME" 2>/dev/null || true
  docker run --rm -v "${VOL_NAME}:/dest" -v "$(dirname "$vol_tar"):/backup:ro" \
    alpine:3.19 tar xzf "/backup/$(basename "$vol_tar")" -C /dest
  echo "Restored volume: $VOL_NAME"
done
```

### Step 5: Verify Recovery

```bash
# Run integration tests
cd /opt/homelab-stack
./tests/run-tests.sh

# Check all containers healthy
docker ps --format 'table {{.Names}}\t{{.Status}}'

# Manual checks:
# - https://traefik.${DOMAIN} — reverse proxy dashboard
# - https://auth.${DOMAIN} — SSO login
# - https://grafana.${DOMAIN} — monitoring dashboards
# - https://nextcloud.${DOMAIN} — cloud storage
```

## Recovery from Cloud Backup

### MinIO/S3

```bash
BACKUP_ID=$(mc ls myminio/homelab-backups/ | sort | tail -1 | awk '{print $NF}')
mc cp -r "myminio/homelab-backups/$BACKUP_ID" /opt/homelab-backups/$BACKUP_ID/
# Then follow Full Recovery Process from Step 2
```

### Backblaze B2

```bash
BACKUP_ID=$(b2 ls b2://homelab-backups/ | sort | tail -1 | awk '{print $NF}')
b2 sync "b2://homelab-backups/$BACKUP_ID" "/opt/homelab-backups/$BACKUP_ID/"
```

### Restic

```bash
restic -r http://restic-server:8000 snapshots
restic -r http://restic-server:8000 restore latest --target /opt/homelab-backups/latest/
```

## Verification Checklist

After recovery, verify:

- [ ] All containers running (`docker ps`)
- [ ] All containers healthy (no `unhealthy` status)
- [ ] Traefik dashboard accessible
- [ ] Authentik SSO login works
- [ ] All service URLs respond with 200
- [ ] Database connections working (check service logs)
- [ ] Monitoring dashboards populated
- [ ] Notifications working (send test via notify.sh)

## Quick Recovery Commands

```bash
# Single service recovery (example: Grafana)
docker compose -f stacks/monitoring/docker-compose.yml up -d grafana
docker restart grafana

# Database-only recovery
./scripts/backup-databases.sh --restore

# Config-only recovery
tar xzf /opt/homelab-backups/LATEST/configs.tar.gz -C /opt/homelab-stack/
```

## Prevention Checklist

To minimize recovery needs:

- [ ] Daily automated backups (cron/systemd timer)
- [ ] Backups synced to cloud (MinIO/B2/R2)
- [ ] 7-day retention minimum
- [ ] Monthly restore drill (test recovery on spare VM)
- [ ] Monitor backup script exit codes
- [ ] ntfy notifications for backup failures
- [ ] Disk space monitoring (alert at 80%)