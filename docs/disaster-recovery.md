# Disaster Recovery Guide

> Complete recovery procedures for HomeLab Stack

## Overview

This document outlines the complete disaster recovery (DR) process for a full system restoration from backups.

## Recovery Time Objectives (RTO)

| Service | RTO | Priority |
|---------|-----|----------|
| Base (Traefik, Portainer) | 5 min | Critical |
| Databases (PostgreSQL, MariaDB) | 15 min | Critical |
| SSO (Authentik) | 10 min | High |
| Storage (Nextcloud, MinIO) | 30 min | High |
| Media (Jellyfin, *arr) | 20 min | Medium |
| Other services | Variable | Low |

## Service Recovery Order

The recovery must follow this order to ensure dependencies are met:

1. **Base Infrastructure**
   - Traefik (reverse proxy)
   - Portainer (container management)
   - Watchtower (auto-updates)

2. **Databases**
   - PostgreSQL
   - MariaDB
   - Redis

3. **SSO & Authentication**
   - Authentik

4. **Storage Services**
   - Nextcloud
   - MinIO

5. **Application Layers**
   - All remaining services

## Full Recovery Procedure

### Step 1: Fresh Host Setup

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone repository
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack
```

### Step 2: Restore Configuration

```bash
# Restore configs from backup
./scripts/backup.sh --restore <backup_id>

# Verify restored files
ls -la config/ stacks/
```

### Step 3: Deploy Base Infrastructure

```bash
# Start base services first
docker compose -f docker-compose.base.yml up -d

# Wait for services to be healthy
sleep 30

# Verify base services
docker compose -f docker-compose.base.yml ps
```

### Step 4: Deploy Databases

```bash
# Start database services
docker compose -f stacks/databases/docker-compose.yml up -d

# Wait for databases to be ready
sleep 60

# Restore database backups
./scripts/backup-databases.sh --restore <backup_id>
```

### Step 5: Deploy SSO

```bash
# Start Authentik
docker compose -f stacks/sso/docker-compose.yml up -d

# Wait for SSO to be ready
sleep 30
```

### Step 6: Deploy Remaining Services

```bash
# Start all services
./scripts/stack-manager.sh start all

# Verify all services
docker compose ps
```

### Step 7: Verification Checklist

- [ ] Traefik dashboard accessible
- [ ] Portainer accessible
- [ ] Authentik login works
- [ ] Database connections successful
- [ ] Storage services operational
- [ ] All services show "healthy" status

## Backup Verification

### Verify Backup Integrity

```bash
# List available backups
./scripts/backup.sh --list

# Verify specific backup
./scripts/backup.sh --verify <backup_id>
```

### Verify Backup Contents

```bash
# Check backup directory
ls -la /opt/homelab-backups/<backup_id>/

# Verify Docker volumes
docker volume ls

# Verify configs
ls -la config/ stacks/
```

## Notification Integration

Backups notify via ntfy when:

- Backup starts
- Backup completes successfully
- Backup fails

Configure ntfy in `.env`:

```env
NTFY_SERVER=https://ntfy.sh
NTFY_TOPIC=homelab-backups
```

## Multiple Backup Targets

The backup system supports multiple targets:

| Target | Configuration |
|--------|---------------|
| Local | `BACKUP_TARGET=local` |
| MinIO/S3 | `BACKUP_TARGET=s3` |
| Backblaze B2 | `BACKUP_TARGET=b2` |
| SFTP | `BACKUP_TARGET=sftp` |
| Cloudflare R2 | `BACKUP_TARGET=r2` |

### S3/MinIO Configuration

```env
# S3-compatible storage
S3_ENDPOINT=https://s3.example.com
S3_BUCKET=backups
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
```

### B2 Configuration

```env
# Backblaze B2
B2_BUCKET=your-bucket
B2_KEY_ID=your-key-id
B2_KEY=your-key
```

### SFTP Configuration

```env
# SFTP remote storage
SFTP_HOST=backup.example.com
SFTP_USER=backup
SFTP_PATH=/backups/homelab
```

## Troubleshooting

### Common Issues

1. **Backup fails with permission denied**
   - Check backup directory permissions
   - Verify PUID/PGID in docker-compose.yml

2. **Restore fails**
   - Verify backup integrity first
   - Check sufficient disk space
   - Ensure services are stopped before restore

3. **ntfy notifications not working**
   - Verify ntfy server accessible
   - Check NTFY_TOPIC and NTFY_SERVER env vars

### Recovery Logs

```bash
# Check backup logs
journalctl -u homelab-backup

# Check Docker logs
docker compose logs duplicati
docker compose logs rest-server
```

## Contact

For support with disaster recovery:

1. Check logs first
2. Verify backup integrity
3. Follow recovery procedure step by step
4. Document any issues for future reference
