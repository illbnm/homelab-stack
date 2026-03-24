# Disaster Recovery Plan

This document provides step-by-step procedures for recovering your HomeLab Stack from a complete system failure.

## Overview

### 3-2-1 Backup Strategy

Our backup implementation follows the 3-2-1 strategy:

| Component | Description |
|-----------|-------------|
| **3 Copies** | Live data + Restic repository + Duplicati cloud backup |
| **2 Media Types** | Local disk + Cloud storage (S3/B2/R2/SFTP) |
| **1 Offsite** | Cloud backup provides offsite resilience |

### Recovery Time Objectives (RTO)

| Stack | Estimated RTO |
|-------|---------------|
| Base (Traefik, Portainer) | 30 minutes |
| Databases | 1-2 hours |
| SSO (Authentik) | 1 hour |
| Storage (Nextcloud, MinIO) | 2-4 hours |
| Media | 2-4 hours |
| Productivity | 1-2 hours |
| Home Automation | 1 hour |
| Monitoring | 30 minutes |
| **Full Recovery** | 8-12 hours |

---

## Phase 1: Prepare New Host

### 1.1 Install Base OS

Install a supported Linux distribution (Ubuntu Server 22.04/24.04 LTS recommended).

### 1.2 Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
```

### 1.3 Clone Repository

```bash
sudo mkdir -p /opt/homelab-stack
sudo chown $USER:$USER /opt/homelab-stack
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab-stack
cd /opt/homelab-stack
```

### 1.4 Restore Environment Files

Restore your `.env` files from backup. This is **CRITICAL** as they contain all secrets and configurations.

```bash
# If you have backed up .env files:
# cp /path/to/backup/.env /opt/homelab-stack/.env
# cp /path/to/backup/stacks/*/.env /opt/homelab-stack/stacks/*/
```

### 1.5 Create Proxy Network

```bash
docker network create proxy
```

---

## Phase 2: Restore Backup System

### 2.1 Deploy Backup Stack

```bash
cd /opt/homelab-stack/stacks/backup
cp .env.example .env
# Edit .env with your backup credentials
nano .env

docker compose up -d
docker compose ps  # Verify both services are healthy
```

### 2.2 Verify Backup Access

```bash
cd /opt/homelab-stack
./scripts/backup.sh --list
```

---

## Phase 3: Restore Infrastructure

### 3.1 Restore Base Stack

```bash
cd /opt/homelab-stack/stacks/base

# Restore Traefik ACME certificates if backed up
# mkdir -p /opt/homelab-stack/config/traefik
# touch /opt/homelab-stack/config/traefik/acme.json
# chmod 600 /opt/homelab-stack/config/traefik/acme.json
# Restore acme.json from backup

docker compose up -d
docker compose ps
```

### 3.2 Verify Base Services

- Traefik Dashboard: `https://traefik.yourdomain.com`
- Portainer: `https://portainer.yourdomain.com`

---

## Phase 4: Restore Databases

### 4.1 Deploy Database Stack

```bash
cd /opt/homelab-stack/stacks/databases
docker compose up -d
docker compose ps
```

### 4.2 Restore Database Data

```bash
# List available backups
/opt/homelab-stack/scripts/backup.sh --list

# Restore to temporary location
/opt/homelab-stack/scripts/backup.sh --restore <BACKUP_ID> --target /tmp/db-restore

# Restore PostgreSQL
docker cp /tmp/db-restore/postgresql_all.sql <postgres_container>:/tmp/
docker exec <postgres_container> psql -U postgres -f /tmp/postgresql_all.sql

# Restore MySQL/MariaDB
docker cp /tmp/db-restore/mysql_all.sql <mysql_container>:/tmp/
docker exec <mysql_container> mysql -u root -p < /tmp/mysql_all.sql
```

---

## Phase 5: Restore SSO

### 5.1 Deploy Authentik

```bash
cd /opt/homelab-stack/stacks/sso
docker compose up -d
docker compose ps
```

### 5.2 Restore Authentik Data

```bash
# Restore Authentik volumes from backup
/opt/homelab-stack/scripts/backup.sh --restore <BACKUP_ID> --target /tmp/authentik-restore

# Stop Authentik
docker compose stop

# Restore volumes
docker run --rm -v authentik-data:/data -v /tmp/authentik-restore:/backup alpine \
  sh -c "cp -a /backup/. /data/"

# Start Authentik
docker compose start
```

---

## Phase 6: Restore Application Stacks

Follow this order for best results:

### 6.1 Network Stack (AdGuard, WireGuard)

```bash
cd /opt/homelab-stack/stacks/network
docker compose up -d
```

### 6.2 Storage Stack (Nextcloud, MinIO)

```bash
cd /opt/homelab-stack/stacks/storage
docker compose up -d
# Restore data volumes from backup
```

### 6.3 Productivity Stack (Gitea, Vaultwarden, Outline)

```bash
cd /opt/homelab-stack/stacks/productivity
docker compose up -d
# Restore data volumes from backup
```

### 6.4 Media Stack

```bash
cd /opt/homelab-stack/stacks/media
docker compose up -d
# Restore config volumes (media files usually don't need backup)
```

### 6.5 Home Automation Stack

```bash
cd /opt/homelab-stack/stacks/home-automation
docker compose up -d
# Restore config volumes
```

### 6.6 Monitoring Stack

```bash
cd /opt/homelab-stack/stacks/monitoring
docker compose up -d
# Restore Prometheus/Grafana data if needed
```

---

## Phase 7: Verification Checklist

After completing recovery, verify each service:

### Base Infrastructure
- [ ] Traefik dashboard accessible at `https://traefik.yourdomain.com`
- [ ] TLS certificates valid
- [ ] Portainer accessible at `https://portainer.yourdomain.com`
- [ ] All containers visible in Portainer

### Databases
- [ ] PostgreSQL running and accepting connections
- [ ] Redis running and responsive
- [ ] MariaDB running and databases restored

### SSO
- [ ] Authentik accessible at `https://auth.yourdomain.com`
- [ ] Can log in with admin credentials
- [ ] OAuth applications configured

### Applications
- [ ] Nextcloud accessible, files present
- [ ] Gitea accessible, repositories present
- [ ] Vaultwarden accessible, vaults intact
- [ ] Jellyfin accessible, libraries working
- [ ] Home Assistant accessible, automations working

### Backup System
- [ ] Restic server healthy
- [ ] Can list backups: `./scripts/backup.sh --list`
- [ ] Can verify backups: `./scripts/backup.sh --verify`

---

## Troubleshooting

### Backup Repository Not Accessible

```bash
# Check restic-server logs
docker logs restic-server

# Verify network connectivity
docker run --rm --network proxy alpine ping restic-server

# Check repository
RESTIC_PASSWORD=your_password docker run --rm --network proxy \
  -e RESTIC_PASSWORD \
  -e RESTIC_REPOSITORY=rest:http://restic-server:8000 \
  restic/restic:0.17.0 snapshots
```

### Volume Permission Issues

```bash
# Fix permissions on restored volumes
docker run --rm -v <volume_name>:/data alpine \
  sh -c "chown -R 1000:1000 /data"
```

### Database Restore Failures

```bash
# PostgreSQL: Check logs
docker logs <postgres_container>

# Manual restore
docker exec -it <postgres_container> psql -U postgres
```

---

## Testing Recovery

Regularly test your backup and recovery procedures:

1. **Monthly**: Run `./scripts/backup.sh --verify`
2. **Quarterly**: Perform a partial restore test
3. **Annually**: Full disaster recovery drill

### Quick Recovery Test

```bash
# Create test restore
./scripts/backup.sh --restore <BACKUP_ID> --target /tmp/test-restore

# Verify contents
ls -la /tmp/test-restore

# Clean up
rm -rf /tmp/test-restore
```

---

## Contact & Support

- GitHub Issues: https://github.com/illbnm/homelab-stack/issues
- Documentation: `/opt/homelab-stack/stacks/*/README.md`

---

*Generated/reviewed with: claude-opus-4-6*