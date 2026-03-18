# Disaster Recovery Guide

Complete recovery procedure for HomeLab Stack from scratch.

## Recovery Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Recovery Order                             │
│                                                              │
│  ① OS & Docker     (15 min)                                 │
│  ② Base Stack      (5 min)   Traefik, Portainer, Watchtower │
│  ③ Databases       (5 min)   PostgreSQL, Redis, MariaDB     │
│  ④ SSO             (5 min)   Authentik                      │
│  ⑤ Restoration     (10 min)  Volumes + database dumps       │
│  ⑥ Other Stacks    (10 min)  Network, Storage, Media, etc.  │
│  ⑦ Verification    (10 min)  Health checks                  │
│                                                              │
│  Total RTO: ~60 minutes                                      │
└──────────────────────────────────────────────────────────────┘
```

## Recovery Time Objectives (RTO)

| Component | RTO | RPO (data loss window) |
|-----------|-----|------------------------|
| Base infrastructure | 20 min | N/A (config only) |
| Databases | 25 min | Last backup (≤24h) |
| SSO / Authentication | 30 min | Last backup |
| All services | 60 min | Last backup |

## Prerequisites

- Fresh server with a supported OS (Ubuntu 22.04+ / Debian 12+ recommended)
- SSH access to the server
- Access to backup storage (local drive, S3, B2, SFTP, or R2)
- Domain DNS pointing to the new server's IP
- Backup encryption key (if backups are encrypted)

## Step-by-Step Recovery

### Step 1: System Setup (15 minutes)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker
docker run --rm hello-world

# Install required tools
sudo apt install -y git curl jq
```

### Step 2: Restore HomeLab Stack Repository (5 minutes)

```bash
# Clone the repository
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab-stack
cd /opt/homelab-stack

# Or restore from backup configs
# (backup.sh restores configs including all stack definitions)
```

### Step 3: Restore Backup Data (10 minutes)

```bash
# If backup is on local drive / USB
export BACKUP_DIR=/mnt/backup-drive
./scripts/backup.sh --list

# If backup is on S3/MinIO
export BACKUP_TARGET=s3
export BACKUP_S3_ENDPOINT=http://minio.example.com:9000
export BACKUP_S3_BUCKET=homelab-backups
export BACKUP_S3_ACCESS_KEY=your-key
export BACKUP_S3_SECRET_KEY=your-secret
./scripts/backup.sh --list

# If backup is encrypted
export BACKUP_ENCRYPTION_KEY=your-passphrase

# Verify backup integrity first
./scripts/backup.sh --verify backup_YYYYMMDD_HHMMSS

# Restore (configs + volumes + databases)
./scripts/backup.sh --restore backup_YYYYMMDD_HHMMSS
```

### Step 4: Deploy Base Stack (5 minutes)

```bash
cd /opt/homelab-stack

# Create shared proxy network
docker network create proxy

# Prepare ACME storage
touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# Verify .env is restored
cat .env  # Should have DOMAIN, ACME_EMAIL, etc.

# Start base stack
docker compose -f stacks/base/docker-compose.yml up -d

# Wait for health checks
sleep 30
docker compose -f stacks/base/docker-compose.yml ps
```

**Verify:**
- [ ] Traefik dashboard accessible at `https://traefik.<DOMAIN>`
- [ ] Portainer accessible at `https://portainer.<DOMAIN>`
- [ ] Watchtower running

### Step 5: Deploy Database Stack (5 minutes)

```bash
docker compose -f stacks/databases/docker-compose.yml up -d

# Wait for databases to be ready
sleep 20

# Verify databases
docker exec homelab-postgres pg_isready
docker exec homelab-redis redis-cli ping
docker exec homelab-mariadb mariadb-admin ping
```

**Note:** Database data was restored in Step 3. If not, restore manually:

```bash
# PostgreSQL
zcat /opt/homelab-backups/backup_*/databases/db_homelab-postgres.sql.gz | \
    docker exec -i homelab-postgres psql -U postgres

# Redis
docker cp /opt/homelab-backups/backup_*/databases/db_homelab-redis.rdb \
    homelab-redis:/data/dump.rdb
docker restart homelab-redis

# MariaDB
zcat /opt/homelab-backups/backup_*/databases/db_homelab-mariadb.sql.gz | \
    docker exec -i homelab-mariadb mysql -u root -p'$MARIADB_ROOT_PASSWORD'
```

### Step 6: Deploy SSO Stack (5 minutes)

```bash
docker compose -f stacks/sso/docker-compose.yml up -d

# Wait for Authentik to initialize
sleep 45

# Verify
curl -sf https://sso.<DOMAIN>/api/v3/root/config/ | jq .
```

**Verify:**
- [ ] Authentik login page accessible
- [ ] Admin account works (restored from backup)

### Step 7: Deploy Remaining Stacks (10 minutes)

Deploy in dependency order:

```bash
# Network (AdGuard, NPM)
docker compose -f stacks/network/docker-compose.yml up -d

# Storage (Nextcloud, MinIO, FileBrowser)
docker compose -f stacks/storage/docker-compose.yml up -d

# Monitoring (Prometheus, Grafana, Loki)
docker compose -f stacks/monitoring/docker-compose.yml up -d

# Media (Jellyfin, *arr suite)
docker compose -f stacks/media/docker-compose.yml up -d

# Productivity (Gitea, Vaultwarden, Outline)
docker compose -f stacks/productivity/docker-compose.yml up -d

# AI (Ollama, Open WebUI)
docker compose -f stacks/ai/docker-compose.yml up -d

# Home Automation (Home Assistant, Node-RED, Mosquitto)
docker compose -f stacks/home-automation/docker-compose.yml up -d

# Notifications (ntfy, Apprise)
docker compose -f stacks/notifications/docker-compose.yml up -d

# Backup (Duplicati, Restic)
docker compose -f stacks/backup/docker-compose.yml up -d
```

Or use the stack manager:
```bash
./scripts/stack-manager.sh up all
```

### Step 8: Verification Checklist (10 minutes)

Run through each service to confirm recovery:

#### Infrastructure
- [ ] Traefik: Dashboard loads, HTTPS working
- [ ] Portainer: Container list shows all services
- [ ] Watchtower: Running, last check time recent

#### Databases
- [ ] PostgreSQL: `docker exec homelab-postgres psql -U postgres -c '\l'`
- [ ] Redis: `docker exec homelab-redis redis-cli INFO keyspace`
- [ ] MariaDB: `docker exec homelab-mariadb mariadb -u root -p -e 'SHOW DATABASES;'`

#### Authentication
- [ ] Authentik: Login works
- [ ] OIDC: Connected apps can authenticate

#### Network
- [ ] AdGuard Home: DNS queries resolving
- [ ] NPM: Proxy hosts configured

#### Storage
- [ ] Nextcloud: Files accessible
- [ ] MinIO: Buckets intact

#### Monitoring
- [ ] Grafana: Dashboards load
- [ ] Prometheus: Targets UP
- [ ] Alertmanager: Receiving alerts

#### Media
- [ ] Jellyfin: Library accessible
- [ ] Sonarr/Radarr: Series/movies listed

#### Productivity
- [ ] Gitea: Repositories accessible
- [ ] Vaultwarden: Vault accessible

#### Home Automation
- [ ] Home Assistant: Dashboard loads
- [ ] Node-RED: Flows present

#### Notifications
- [ ] ntfy: Test notification: `curl -d "Recovery test" ntfy.<DOMAIN>/test`

## Partial Recovery Scenarios

### Scenario: Single Service Failure

```bash
# Restart the failed service
docker compose -f stacks/<stack>/docker-compose.yml restart <service>

# If data is corrupted, restore just that stack's volumes
./scripts/backup.sh --target <stack> --restore backup_YYYYMMDD_HHMMSS
```

### Scenario: Database Corruption

```bash
# Stop the database stack
docker compose -f stacks/databases/docker-compose.yml down

# Remove corrupted volume
docker volume rm postgres-data

# Recreate and start
docker compose -f stacks/databases/docker-compose.yml up -d
sleep 20

# Restore from backup
zcat /opt/homelab-backups/backup_*/databases/db_homelab-postgres.sql.gz | \
    docker exec -i homelab-postgres psql -U postgres
```

### Scenario: Docker Host Migration

```bash
# On OLD host: create final backup
./scripts/backup.sh --target all

# Transfer backup to new host
rsync -avz /opt/homelab-backups/ newhost:/opt/homelab-backups/

# On NEW host: follow Steps 1-8 above
```

### Scenario: Disk Failure (data loss)

```bash
# If offsite backup exists (S3/B2/SFTP)
export BACKUP_TARGET=s3  # or b2, sftp, r2
# Set credentials...
./scripts/backup.sh --list
./scripts/backup.sh --restore <latest-backup-id>
```

## Backup Verification Schedule

| Frequency | Action |
|-----------|--------|
| Daily | Automated backup via cron/systemd |
| Weekly | Automated integrity verification |
| Monthly | Manual test restore to staging |
| Quarterly | Full DR drill (restore to fresh server) |

## Emergency Contacts & Resources

| Resource | Location |
|----------|----------|
| Backup directory | `/opt/homelab-backups/` |
| Backup logs | `/var/log/homelab-backup.log` |
| Encryption key | **Store separately from backups!** |
| Repository | `https://github.com/illbnm/homelab-stack` |
| Docker logs | `docker compose -f stacks/<stack>/docker-compose.yml logs` |

## Key Files

| File | Purpose |
|------|---------|
| `scripts/backup.sh` | Backup/restore CLI |
| `stacks/backup/docker-compose.yml` | Duplicati + Restic services |
| `stacks/backup/.env.example` | Backup configuration template |
| `scripts/homelab-backup.cron` | Cron job definition |
| `scripts/homelab-backup.service` | Systemd service unit |
| `scripts/homelab-backup.timer` | Systemd timer unit |
| `docs/disaster-recovery.md` | This document |
