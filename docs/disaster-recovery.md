# 🛡️ HomeLab Disaster Recovery Runbook (3-2-1 Strategy)

> Comprehensive emergency disaster recovery and bare-metal restoration guide.

---

## 📐 The 3-2-1 Architecture
- **3 Copies:** Live cluster + Local encrypted snapshots + Remote cloud vault.
- **2 Media Types:** NVMe volume storage + S3 object storage / Restic append-only repo.
- **1 Offsite Location:** Cloudflare R2 / Backblaze B2 / MinIO secondary location.

---

## ⏱️ Recovery Time & Point Objectives
- **RTO (Recovery Time Objective):** < 15 minutes to operational baseline.
- **RPO (Recovery Point Objective):** Max 24 hours (nightly automated snapshots).

---

## 🚨 Bare-Metal Step-by-Step Restoration Procedure

### Step 1: Base System Initialization (Minute 0 - 3)
1. Install Docker & Compose on clean host:
   ```bash
   curl -fsSL https://get.docker.com | sh
   git clone https://github.com/NePreby/homelab-stack.git /opt/homelab
   cd /opt/homelab
   ```
2. Create external overlay network:
   ```bash
   docker network create proxy
   ```

### Step 2: Restore Configuration & Secret Keys (Minute 3 - 5)
```bash
./scripts/backup.sh --restore <snapshot_id>
```

### Step 3: Layered Stack Startup Sequence
To prevent race conditions, services must be brought up in strict topological order:
1. **Base Infrastructure:**
   ```bash
   docker compose -f stacks/base/docker-compose.yml up -d
   ```
2. **Shared Databases (PostgreSQL / Redis / MariaDB):**
   ```bash
   docker compose -f stacks/databases/docker-compose.yml up -d
   ./scripts/init-databases.sh
   ```
3. **Identity & SSO (Authentik):**
   ```bash
   docker compose -f stacks/sso/docker-compose.yml up -d
   ```
4. **Application Stacks (Storage, Media, Productivity):**
   ```bash
   ./scripts/stack-manager.sh start storage
   ./scripts/stack-manager.sh start media
   ```

---

## ✅ Post-Restoration Verification Checklist
- [ ] Traefik reverse proxy dashboard reachable over HTTPS.
- [ ] Database instances healthy: `pg_isready` returns 0.
- [ ] Authentik OIDC provider tokens issuing valid sessions.
- [ ] Application volume data verified via `./scripts/backup.sh --verify`.
