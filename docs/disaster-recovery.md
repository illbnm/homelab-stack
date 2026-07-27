# 🚨 Homelab Disaster Recovery & Bare-Metal Restoration Guide

This document outlines the step-by-step procedure to restore the Homelab infrastructure from scratch in the event of hardware failure or data corruption.

---

## 🎯 3-2-1 Backup Strategy Overview

- **3 Copies of Data**: Live Docker volumes, local tarball archives (`/data/backups`), and remote cloud backups.
- **2 Media Types**: NVMe local storage + S3 object storage (MinIO / Backblaze B2).
- **1 Offsite Location**: Remote S3 / Cloudflare R2 / SFTP backup target (`BACKUP_TARGET=s3`).

---

## ⏳ Recovery Order & RTO (Recovery Time Objective)

| Priority | Stack | Services | Estimated RTO | Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **1. Core Infra** | `stacks/base` | Traefik, Portainer, Watchtower | **5 mins** | Docker Engine |
| **2. Database Layer** | `stacks/databases` | PostgreSQL, Redis, MariaDB | **10 mins** | Base Network |
| **3. SSO / Auth** | `stacks/sso` | Authentik | **10 mins** | PostgreSQL, Redis |
| **4. Storage / Cloud** | `stacks/storage` | Nextcloud FPM, MinIO, FileBrowser | **15 mins** | PostgreSQL, Redis, Authentik |
| **5. Applications** | Media, Automation, Productivity | Jellyfin, Gitea, Home Assistant | **20 mins** | All Core Layers |

**Total System RTO:** **~60 Minutes**

---

## 🛠️ Step-by-Step Bare-Metal Recovery Procedure

### 1. Environment Preparation
Install Git, Docker, and Docker Compose on the target server:

```bash
curl -fsSL https://get.docker.com | sh
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab-stack
cd /opt/homelab-stack
```

### 2. Restore Configuration & `.env`

Fetch the latest configuration backup:

```bash
./scripts/backup.sh --restore latest --target all
```

### 3. Restore Databases

Execute database restoration from dump files:

```bash
# Restore PostgreSQL
cat /data/backups/databases/pg_dumpall_*.sql | docker exec -i homelab-postgres psql -U postgres
```

### 4. Verification Checklist

- [ ] Traefik dashboard accessible at `https://traefik.${DOMAIN}`
- [ ] PostgreSQL and Redis healthchecks reporting `healthy`
- [ ] Authentik SSO login functional
- [ ] Nextcloud, Gitea, and Media services accessible without SSL errors
