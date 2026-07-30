# Disaster Recovery Plan — HomeLab Stack

## Overview

This document describes the complete disaster recovery procedure for restoring
the entire HomeLab Stack from backup on a fresh host.

## 3-2-1 Backup Strategy

- **3** copies of data (live + local backup + offsite)
- **2** different media (local disk + cloud/S3/B2)
- **1** offsite copy (S3/B2/R2/SFTP)

## Backup Targets

| Target | Config Key | Description |
|--------|-----------|-------------|
| Local | `BACKUP_TARGET=local` | Restic REST server on local disk |
| S3 (MinIO/AWS) | `BACKUP_TARGET=s3` | S3-compatible object storage |
| Backblaze B2 | `BACKUP_TARGET=b2` | B2 cloud storage |
| SFTP | `BACKUP_TARGET=sftp` | Remote server via SSH |
| Cloudflare R2 | `BACKUP_TARGET=r2` | R2 object storage |

## Recovery Time Objective (RTO)

| Stack | Estimated Recovery Time | Priority |
|-------|------------------------|----------|
| Base (Traefik) | 5 min | P0 |
| Databases | 10 min | P0 |
| SSO (Authentik) | 15 min | P1 |
| Monitoring | 10 min | P1 |
| Storage | 30 min | P2 |
| Productivity | 15 min | P2 |
| AI | 10 min | P3 |
| Media | 45 min | P3 |
| Network | 5 min | P1 |
| Notifications | 5 min | P3 |

**Total estimated RTO: ~2.5 hours (full recovery)**

## Recovery Point Objective (RPO)

- Daily backups at 2:00 AM
- Maximum data loss: 24 hours
- For critical stacks (databases, SSO): consider hourly snapshots

## Full Recovery Procedure (Fresh Host)

### Phase 1: Infrastructure (30 min)

```bash
# 1. Install Docker + Docker Compose
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin jq curl

# 2. Clone the repo
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# 3. Create the homelab network
docker network create homelab

# 4. Configure environment
cp stacks/backup/.env.example stacks/backup/.env
nano stacks/backup/.env  # Set RESTIC_REPOSITORY, RESTIC_PASSWORD, backup target

# 5. Start backup stack first
cd stacks/backup && docker compose up -d

# 6. List available backups
./scripts/backup.sh --list
```

### Phase 2: Base Stack (10 min)

```bash
# 1. Restore base stack data
./scripts/backup.sh --restore <snapshot-id> --target base

# 2. Start base stack
cd stacks/base && docker compose up -d

# 3. Verify
curl http://localhost:8080/api/version  # Traefik
curl http://localhost:9000/api/status  # Portainer
```

### Phase 3: Databases (15 min)

```bash
# 1. Restore database data
./scripts/backup.sh --restore <snapshot-id> --target databases

# 2. Start databases
cd stacks/databases && docker compose up -d

# 3. Verify
docker exec postgres pg_isready -U postgres
docker exec redis redis-cli ping
```

### Phase 4: SSO (20 min)

```bash
# 1. Restore SSO data
./scripts/backup.sh --restore <snapshot-id> --target sso

# 2. Start SSO stack
cd stacks/sso && docker compose up -d

# 3. Wait for healthy
docker compose ps  # All healthy

# 4. Re-provision OIDC providers
./scripts/authentik-setup.sh
```

### Phase 5: Remaining Stacks (45 min)

Restore and start in priority order:

```bash
for stack in monitoring network productivity storage ai media notifications; do
  ./scripts/backup.sh --restore <snapshot-id> --target $stack
  cd stacks/$stack && docker compose up -d
  cd ../..
done
```

### Phase 6: Verification (15 min)

```bash
# Run full test suite
./tests/run-tests.sh --all

# Verify backup integrity
./scripts/backup.sh --verify
```

## Recovery Checklist

- [ ] Docker installed and running
- [ ] homelab network created
- [ ] Backup stack started and accessible
- [ ] Backups listed and snapshot IDs identified
- [ ] Base stack restored and verified
- [ ] Databases restored and connections verified
- [ ] SSO stack restored and admin login tested
- [ ] OIDC providers re-provisioned
- [ ] All application stacks restored
- [ ] Traefik routes verified (all services accessible)
- [ ] DNS records point to new host
- [ ] TLS certificates renewed
- [ ] Full test suite passes: `./tests/run-tests.sh --all`
- [ ] Backup integrity verified: `./scripts/backup.sh --verify`
- [ ] Notification system tested (ntfy)

## Partial Recovery (Single Stack)

```bash
# Restore a single stack
./scripts/backup.sh --restore <snapshot-id> --target media

# Restart only that stack
cd stacks/media && docker compose down && docker compose up -d

# Verify
./tests/run-tests.sh --stack media
```

## Backup Verification (Weekly)

```bash
# Verify all backup integrity
./scripts/backup.sh --verify

# List all snapshots
./scripts/backup.sh --list
```

## Testing Recovery (Monthly)

1. Spin up a test VM
2. Follow the full recovery procedure
3. Run the test suite
4. Document any issues
5. Update this document

## Emergency Contacts

- Backup server admin: (configure in notification settings)
- ntfy topic: `${NTFY_URL}/${NTFY_TOPIC}`
- Backup failure alerts are sent automatically via ntfy