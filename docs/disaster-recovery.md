# Disaster Recovery (DR) Guide

## Overview

This document describes the complete disaster recovery procedure for the HomeLab Stack, following the **3-2-1 backup strategy**:

> **3** copies of data — **2** different storage media — **1** offsite

| Copy | Type | Location |
|------|------|----------|
| Primary | Live data | Docker volumes / host filesystem |
| Backup #1 | Local/attached storage | `/opt/homelab-backups` or MinIO/Backblaze B2 |
| Backup #2 | Remote/offsite | Cloudflare R2, SFTP server, or Backblaze B2 |

---

## Backup Types

### Full Stack Backup (`--target all`)
Backs up all Docker volumes, configurations, and databases.

### Media Backup (`--target media`)
Backs up media-related volumes only (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent).

---

## Backup Schedule

Automated via **systemd timer** (recommended) or **crontab**:

### systemd Timer (Recommended)

```bash
# Install the timer and service
sudo cp homelab-stack/systemd/homelab-backup.service /etc/systemd/system/
sudo cp homelab-stack/systemd/homelab-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer

# Check status
sudo systemctl status homelab-backup.timer
sudo systemctl list-timers --all | grep homelab-backup
```

### Crontab (Alternative)

```bash
# Edit crontab
crontab -e

# Add line: run daily at 2:00 AM
0 2 * * * /opt/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

---

## Backup Commands

### Create a Full Backup

```bash
cd /opt/homelab-stack
./scripts/backup.sh --target all
```

### Create a Media-Only Backup

```bash
./scripts/backup.sh --target media
```

### Dry Run (Preview)

```bash
./scripts/backup.sh --target all --dry-run
```

### List Available Backups

```bash
./scripts/backup.sh --list
```

### Verify a Backup

```bash
./scripts/backup.sh --verify --restore <backup_id>
```

### Restore from Backup

```bash
# Full restore
./scripts/backup.sh --restore <backup_id>

# Example with actual backup ID
./scripts/backup.sh --restore 20241015_020000
```

---

## Backup Targets Configuration

Set `BACKUP_TARGET` in `config/.env`:

```bash
# Local directory (default)
BACKUP_TARGET=local

# S3-compatible (MinIO, AWS S3)
BACKUP_TARGET=s3

# Backblaze B2
BACKUP_TARGET=b2

# SFTP/SCP
BACKUP_TARGET=sftp

# Cloudflare R2 (S3-compatible)
BACKUP_TARGET=r2
```

### S3/MinIO Configuration

```bash
BACKUP_TARGET=s3
AWS_ACCESS_KEY_ID=your_key_id
AWS_SECRET_ACCESS_KEY=your_secret
AWS_ENDPOINT=https://minio.example.com:9000  # omit for AWS S3
AWS_BUCKET=homelab-backups
AWS_REGION=us-east-1
```

### Backblaze B2 Configuration

```bash
BACKUP_TARGET=b2
B2_ACCOUNT_ID=your_account_id
B2_ACCOUNT_KEY=your_application_key
B2_BUCKET=homelab-backups
```

### SFTP Configuration

```bash
BACKUP_TARGET=sftp
SFTP_HOST=backup.example.com
SFTP_PORT=22
SFTP_USER=backups
SFTP_PASSWORD=your_password
# OR use SSH key:
SFTP_KEY=/root/.ssh/backup_id_rsa
SFTP_REMOTE_DIR=/backups/homelab
```

### Cloudflare R2 Configuration

```bash
BACKUP_TARGET=r2
AWS_ACCESS_KEY_ID=your_r2_access_key
AWS_SECRET_ACCESS_KEY=your_r2_secret
AWS_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
AWS_BUCKET=homelab-backups
AWS_REGION=auto
```

---

## Full Restore Procedure

### Prerequisites

- Fresh Linux installation (Ubuntu 22.04+ recommended)
- Docker Engine 24+ and Docker Compose v2 installed
- Domain name configured and accessible
- Backup accessible from the new host

### Step 1: Prepare New Host

```bash
# Install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2

# Clone the repository
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab-stack
cd /opt/homelab-stack

# Copy and configure environment
cp .env.example config/.env
nano config/.env  # fill in all required values
```

### Step 2: Recreate Docker Networks

```bash
docker network create proxy 2>/dev/null || true
docker network create databases 2>/dev/null || true
docker network create sso 2>/dev/null || true
```

### Step 3: Restore Configurations

```bash
# Download/restore configs from backup
./scripts/backup.sh --restore <backup_id>
```

### Step 4: Launch Base Infrastructure

**Critical:** Start services in the correct order. Each layer must be healthy before proceeding.

```
Layer 0 (Foundation)
├── Traefik (reverse proxy + TLS)
└── Portainer (container management)
    ↓ wait 30s
Layer 1 (Databases)
├── PostgreSQL (shared)
├── Redis (shared)
└── MariaDB (shared)
    ↓ wait until healthy (docker ps | grep healthy)
Layer 2 (SSO)
├── Authentik (PostgreSQL + Redis)
    ↓ wait until healthy (~60s for first boot)
Layer 3 (Core Services)
├── Monitoring (Prometheus, Grafana, Loki)
├── Storage (Nextcloud, MinIO)
└── Network (AdGuard, WireGuard)
    ↓
Layer 4 (Application Stacks)
├── Media (Jellyfin, Sonarr, Radarr...)
├── Productivity (Gitea, Outline, Vaultwarden...)
├── AI (Ollama, Open WebUI)
└── Home Automation (Home Assistant, Node-RED...)
```

```bash
# Layer 0 — Base
docker compose -f stacks/base/docker-compose.yml up -d
sleep 30

# Layer 1 — Databases
docker compose -f stacks/databases/docker-compose.yml up -d
# Wait for healthy
until docker inspect --format='{{.State.Health.Status}}' homelab-postgres | grep -q healthy; do sleep 5; done
until docker inspect --format='{{.State.Health.Status}}' homelab-redis | grep -q healthy; do sleep 5; done
until docker inspect --format='{{.State.Health.Status}}' homelab-mariadb | grep -q healthy; do sleep 5; done

# Layer 2 — SSO
cd /opt/homelab-stack/stacks/sso
docker compose up -d
# Wait for healthy
until docker inspect --format='{{.State.Health.Status}}' authentik-server | grep -q healthy; do sleep 10; done
# Run post-setup (creates OAuth clients)
cd /opt/homelab-stack
./scripts/setup-authentik.sh

# Layer 3 — Core stacks (example: monitoring)
docker compose -f stacks/monitoring/docker-compose.yml up -d

# Layer 4 — Application stacks
docker compose -f stacks/media/docker-compose.yml up -d
docker compose -f stacks/productivity/docker-compose.yml up -d
docker compose -f stacks/ai/docker-compose.yml up -d
```

### Step 5: Verify Restore

Run the verification checklist below.

---

## Service Restore Order

**Critical:** Restoring services out of order may result in data corruption or authentication failures.

```
Base → Databases → SSO → Monitoring → Storage → Network → Applications
```

| Order | Service | Reason |
|-------|---------|--------|
| 1 | Traefik | All services depend on reverse proxy |
| 2 | Portainer | Container management needed |
| 3 | PostgreSQL | Most services depend on DB |
| 4 | Redis | SSO, and some apps depend on cache |
| 5 | MariaDB | Nextcloud and other apps |
| 6 | Authentik | SSO must be up before apps that use it |
| 7 | Monitoring | Can be restored anytime after DBs |
| 8 | Nextcloud | Depends on MariaDB |
| 9 | MinIO | Depends on PostgreSQL |
| 10 | Media stack | Independent, restore last |
| 11 | Other stacks | Independent ordering |

---

## Estimated RTO (Recovery Time Objective)

| Scenario | RTO Estimate | Notes |
|----------|--------------|-------|
| Full stack restore (new host) | 2–4 hours | Depends on data size and network speed |
| Volume restore only | 30–60 min | Docker volume corruption fix |
| Config restore only | 15–30 min | Accidental config deletion |
| Database restore | 20–40 min | Depends on DB size |
| Single service failure | 5–15 min | Redeploy container from backup |

### Factors Affecting RTO

- **Network speed** — Large backups from cloud storage take longer
- **Data volume** — Media files are the largest component
- **Hardware** — New host provisioning time
- **Backup freshness** — How much data needs replaying after backup

---

## Verification Checklist

After any restore, verify all critical services are operational:

### Base Infrastructure
- [ ] Traefik dashboard accessible (`https://traefik.<domain>`)
- [ ] Portainer accessible (`https://portainer.<domain>`)
- [ ] All containers running (`docker ps -a`)
- [ ] Docker networks exist (`docker network ls`)

### Databases
- [ ] PostgreSQL healthy (`docker inspect homelab-postgres`)
- [ ] Redis responding (`docker exec homelab-redis redis-cli ping`)
- [ ] MariaDB responding (`docker exec homelab-mariadb mariadb -u root -e "SELECT 1"`)

### SSO (Authentik)
- [ ] Authentik web UI accessible (`https://auth.<domain>`)
- [ ] Can log in to Authentik admin
- [ ] OAuth/OIDC endpoints responding
- [ ] Other services can authenticate via SSO

### Monitoring
- [ ] Grafana accessible (`https://grafana.<domain>`)
- [ ] Prometheus targets all up
- [ ] Loki receiving logs
- [ ] Alertmanager accessible

### Storage
- [ ] Nextcloud accessible (`https://nextcloud.<domain>`)
- [ ] MinIO console accessible (`https://minio.<domain>`)
- [ ] Files intact after restore

### Media Stack
- [ ] Jellyfin accessible (`https://media.<domain>`)
- [ ] Sonarr/Radarr/Prowlarr accessible
- [ ] Media library metadata intact
- [ ] Download client (qBittorrent) functional

### Notifications
- [ ] ntfy accessible (`https://ntfy.<domain>`)
- [ ] Apprise API accessible
- [ ] Test notification sent

### Productivity Stack
- [ ] Gitea accessible (`https://git.<domain>`)
- [ ] Vaultwarden accessible (`https://vault.<domain>`)
- [ ] Outline accessible (`https://outline.<domain>`)

---

## Volume Backup List

These Docker volumes are included in `--target all` backups:

| Volume | Service | Priority |
|--------|---------|----------|
| `portainer-data` | Portainer | Critical |
| `postgresql_data` | PostgreSQL | Critical |
| `redis_data` | Redis | Critical |
| `mariadb-data` | MariaDB | Critical |
| `authentik_media` | Authentik | Critical |
| `authentik_templates` | Authentik | Medium |
| `grafana-data` | Grafana | Medium |
| `prometheus-data` | Prometheus | Medium |
| `loki-data` | Loki | Low |
| `traefik-logs` | Traefik | Low |

These volumes are included in `--target media`:

| Volume | Service |
|--------|---------|
| `jellyfin-config` | Jellyfin |
| `sonarr-config` | Sonarr |
| `radarr-config` | Radarr |
| `prowlarr-config` | Prowlarr |
| `qbittorrent-config` | qBittorrent |

---

## Notification Setup

Backup success/failure notifications are sent via **ntfy**.

```bash
# ntfy configuration in config/.env
NTFY_HOST=https://ntfy.example.com   # your ntfy server
NTFY_TOPIC=homelab-backup           # notification topic
```

To receive notifications on your phone:
1. Install the ntfy app (Android/iOS)
2. Subscribe to the `homelab-backup` topic
3. Optionally set a password via `NTFY_TOPIC=homelab-backup:your_password`

---

## Duplicati Integration (Optional)

For encrypted cloud backups, you can use **Duplicati** running in the homelab:

```bash
# Access Duplicati at https://duplicati.<domain>
# Configure backup jobs using Duplicati's web UI
# Recommended: encrypt backups before sending to cloud storage
```

Duplicati is available at `https://duplicati.<domain>` when the notifications stack is running.

---

## Testing the Restore Process

**Important:** Test your backups regularly — don't wait for a disaster.

```bash
# 1. Do a dry-run backup
./scripts/backup.sh --target all --dry-run

# 2. Create a test backup
./scripts/backup.sh --target all

# 3. List backups
./scripts/backup.sh --list

# 4. Verify the latest backup
LATEST=$(ls -td /opt/homelab-backups/*/ | head -1 | xargs basename)
./scripts/backup.sh --verify --restore "$LATEST"

# 5. On a test environment, try restoring:
./scripts/backup.sh --restore "$LATEST"
```

---

## Troubleshooting

### Backup fails with "permission denied"

Ensure the backup script runs as root or with sudo:
```bash
sudo ./scripts/backup.sh --target all
```

### SFTP upload fails

Verify SSH key authentication:
```bash
ssh -i /root/.ssh/backup_id_rsa backups@backup.example.com ls /backups
```

### ntfy notifications not working

Check that ntfy is accessible:
```bash
curl -s https://ntfy.example.com/v1/health
```

### Volume restore fails

Some volumes require the container to be stopped first:
```bash
docker stop <service>
docker volume rm <volume>
./scripts/backup.sh --restore <backup_id>
docker start <service>
```

### S3/MinIO credentials wrong

Test credentials:
```bash
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy aws s3 ls --endpoint-url https://minio.example.com
```
