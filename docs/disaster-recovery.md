# HomeLab Disaster Recovery Guide

Complete guide for recovering your HomeLab stack from scratch on a new host.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Recovery Timeline (RTO)](#recovery-timeline-rto)
- [Full Recovery Procedure](#full-recovery-procedure)
- [Service Recovery Order](#service-recovery-order)
- [Individual Service Recovery](#individual-service-recovery)
- [Verification Checklist](#verification-checklist)
- [Common Issues](#common-issues)
- [Backup Strategy (3-2-1)](#backup-strategy-3-2-1)

---

## Overview

This document describes the complete process to restore the HomeLab stack on a
brand-new host from backup. The recovery follows the 3-2-1 backup strategy:

- **3 copies** of data: local restic repo, cloud backup, exported tarballs
- **2 different media**: local disk + cloud storage (S3/B2/R2/SFTP)
- **1 offsite copy**: cloud backup for disaster scenarios

## Prerequisites

Before starting recovery, ensure the new host has:

- [ ] Ubuntu 22.04+ or Debian 12+ installed
- [ ] Docker 24+ and Docker Compose v2 installed
- [ ] Network connectivity to backup location (local NFS, S3, B2, etc.)
- [ ] Access credentials for backup target
- [ ] Domain DNS pointing to new host IP
- [ ] `curl`, `git`, `bash` available

## Recovery Timeline (RTO)

| Phase | Task | Duration | Cumulative |
|-------|------|----------|------------|
| 1 | Host setup + Docker install | ~10 min | 10 min |
| 2 | Clone repo + configure .env | ~5 min | 15 min |
| 3 | Download backup from remote | ~15 min | 30 min |
| 4 | Restore volumes + databases | ~20 min | 50 min |
| 5 | Start base infrastructure | ~5 min | 55 min |
| 6 | Start all services | ~10 min | 65 min |
| 7 | Verify + fix issues | ~15 min | **80 min** |

**Estimated RTO: ~80 minutes** (depends on backup size and network speed)

## Full Recovery Procedure

### Step 1: Prepare New Host

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker
docker --version
docker compose version
```

### Step 2: Clone Repository

```bash
git clone https://github.com/illbnm/homelab-stack.git ~/homelab-stack
cd ~/homelab-stack
```

### Step 3: Configure Environment

```bash
cp .env.example .env
# Edit .env with your values:
#   - DOMAIN
#   - All passwords/secrets
#   - Backup credentials
nano .env
```

### Step 4: Retrieve Backup

**From local/NFS:**
```bash
# If backup is on NFS
sudo mount -t nfs backup-server:/backups /mnt/backup

# Copy to expected location
sudo mkdir -p /opt/homelab-backups
sudo cp -r /mnt/backup/* /opt/homelab-backups/
```

**From S3/MinIO:**
```bash
# Install restic
sudo apt install -y restic

# Pull backup from S3
export RESTIC_REPOSITORY="s3:https://minio.yourdomain.com/homelab-backups"
export RESTIC_PASSWORD="your-restic-password"
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

restic snapshots                    # List available snapshots
restic restore latest --target /opt/homelab-backups/restore
```

**From Backblaze B2:**
```bash
export RESTIC_REPOSITORY="b2:your-bucket-name"
export RESTIC_PASSWORD="your-restic-password"
export B2_ACCOUNT_ID="your-account-id"
export B2_ACCOUNT_KEY="your-account-key"

restic restore latest --target /opt/homelab-backups/restore
```

### Step 5: Run Disaster Recovery Script

```bash
cd ~/homelab-stack

# Make scripts executable
chmod +x stacks/backup/scripts/*.sh

# Run full restore (uses latest backup)
./stacks/backup/scripts/restore.sh --from-latest

# OR restore from specific backup
./stacks/backup/scripts/restore.sh --from 20260515_020000
```

### Step 6: Verify Services

```bash
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check health status
docker ps --filter "health=healthy" --format "{{.Names}}"

# Test web endpoints
curl -sf https://traefik.${DOMAIN}/ping
curl -sf https://auth.${DOMAIN}
curl -sf https://grafana.${DOMAIN}/api/health
```

## Service Recovery Order

Services must be started in this specific order due to dependencies:

```
Phase 1 — Base Infrastructure
  └── Traefik (reverse proxy)
  └── Portainer (container management)
  └── Watchtower (auto-updates)

Phase 2 — Databases
  └── PostgreSQL (required by: Authentik, Nextcloud, Gitea, Outline)
  └── Redis (required by: Authentik, Nextcloud)
  └── MariaDB (required by: Home Assistant)

Phase 3 — SSO
  └── Authentik (required by: all services using SSO)

Phase 4 — Monitoring
  └── Prometheus
  └── Grafana
  └── Loki + Promtail
  └── Alertmanager

Phase 5 — Storage & Network
  └── Nextcloud
  └── MinIO
  └── FileBrowser
  └── WireGuard
  └── Cloudflare DDNS

Phase 6 — Application Services
  └── Media stack (Jellyfin, Sonarr, Radarr, etc.)
  └── AI stack (Ollama, Open WebUI)
  └── Productivity (Gitea, Outline, Vaultwarden)
  └── Home Automation (Home Assistant)
  └── Notifications (ntfy, Gotify, Apprise)

Phase 7 — Dashboard & Backup
  └── Homepage/Dashboard
  └── Backup stack (Duplicati, Restic)
```

## Individual Service Recovery

### PostgreSQL

```bash
# Start database stack
cd stacks/databases && docker compose up -d postgres

# Wait for ready
docker exec homelab-postgres pg_isready -U postgres

# Restore dump
docker exec -i homelab-postgres psql -U postgres < /opt/homelab-backups/<ID>/postgresql_all.sql

# Verify databases
docker exec homelab-postgres psql -U postgres -c "\l"
```

### Authentik (SSO)

```bash
# Ensure PostgreSQL and Redis are running first
cd stacks/sso && docker compose up -d

# Wait for migrations
sleep 30

# Verify
curl -sf https://auth.${DOMAIN}/-/health/ready/
```

### Grafana

```bash
cd stacks/monitoring && docker compose up -d grafana

# Verify OAuth still works
curl -sf https://grafana.${DOMAIN}/api/health
```

### Nextcloud

```bash
cd stacks/storage && docker compose up -d nextcloud

# Run maintenance repair if needed
docker exec -u www-data nextcloud php occ maintenance:repair

# Verify
curl -sf https://nextcloud.${DOMAIN}/status.php
```

## Verification Checklist

After recovery, verify each item:

### Infrastructure
- [ ] Traefik dashboard accessible: `https://traefik.${DOMAIN}`
- [ ] SSL certificates valid (check browser lock icon)
- [ ] Portainer accessible: `https://portainer.${DOMAIN}`
- [ ] All Docker networks created: `docker network ls`

### Databases
- [ ] PostgreSQL accepting connections: `pg_isready`
- [ ] All databases present: `psql -c "\l"`
- [ ] Redis responding: `redis-cli ping`
- [ ] MariaDB accepting connections

### SSO
- [ ] Authentik admin login works
- [ ] OAuth flows work for Grafana
- [ ] OAuth flows work for Gitea
- [ ] OAuth flows work for Outline

### Storage
- [ ] Nextcloud web UI accessible
- [ ] Files visible in Nextcloud
- [ ] MinIO console accessible
- [ ] FileBrowser shows files

### Monitoring
- [ ] Grafana dashboards loading
- [ ] Prometheus scraping targets
- [ ] Loki receiving logs
- [ ] Alerts configured

### Applications
- [ ] All services accessible via Traefik
- [ ] Media libraries intact
- [ ] Gitea repositories accessible
- [ ] Vaultwarden vaults accessible

### Backup
- [ ] Backup stack running
- [ ] Test backup completes successfully
- [ ] Notifications working (ntfy)
- [ ] Scheduled backup active

## Common Issues

### Container fails to start

```bash
# Check logs
docker logs <container-name> --tail 50

# Common fix: permissions
docker exec <container-name> chown -R <user>:<group> /data
```

### Database connection refused

```bash
# PostgreSQL not ready — wait and retry
docker exec homelab-postgres pg_isready
# If stuck: restart
docker restart homelab-postgres
```

### SSL certificate issues

```bash
# Force Traefik to re-request certificates
rm -f config/traefik/acme.json
touch config/traefik/acme.json && chmod 600 config/traefik/acme.json
docker restart traefik
```

### Authentik SSO not working

```bash
# Reset Authentik
cd stacks/sso
docker compose down -v
docker compose up -d
# Re-run setup
../../scripts/setup-authentik.sh
```

### Volume permission errors

```bash
# Fix ownership
docker run --rm -v <volume-name>:/data alpine chown -R 1000:1000 /data
```

## Backup Strategy (3-2-1)

### Current Configuration

```
┌─────────────────────────────────────────────────────┐
│                  3-2-1 Backup Strategy               │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐        │
│  │ Copy 1   │   │ Copy 2   │   │ Copy 3   │        │
│  │ Local    │   │ Restic   │   │ Cloud    │        │
│  │ Tarballs │   │ Repo     │   │ (Duplicati│       │
│  │          │   │          │   │  or Restic)│       │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘        │
│       │              │              │               │
│  ┌────┴─────┐   ┌────┴─────┐   ┌────┴─────┐        │
│  │ Medium 1 │   │ Medium 1 │   │ Medium 2 │        │
│  │ Local    │   │ Local    │   │ Cloud    │        │
│  │ Disk     │   │ Disk     │   │ (S3/B2/  │        │
│  │          │   │          │   │  R2/SFTP)│        │
│  └──────────┘   └──────────┘   └──────────┘        │
│                                                      │
│  Retention: 7 days                                   │
│  Schedule: Daily at 02:00                            │
│  Notifications: ntfy on success/failure              │
└─────────────────────────────────────────────────────┘
```

### Backup Targets

Configure in `.env`:

```bash
# Local only
BACKUP_TARGET=local

# S3-compatible (MinIO, AWS)
BACKUP_TARGET=s3
S3_ENDPOINT=https://minio.example.com
S3_BUCKET=homelab-backups
S3_ACCESS_KEY=...
S3_SECRET_KEY=...

# Backblaze B2
BACKUP_TARGET=b2
B2_ACCOUNT_ID=...
B2_ACCOUNT_KEY=...
B2_BUCKET=homelab-backups

# SFTP
BACKUP_TARGET=sftp
SFTP_HOST=backup.example.com
SFTP_USER=backup
SFTP_PATH=/backups/homelab

# Cloudflare R2
BACKUP_TARGET=r2
R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
R2_BUCKET=homelab-backups
R2_ACCESS_KEY=...
R2_SECRET_KEY=...
```
