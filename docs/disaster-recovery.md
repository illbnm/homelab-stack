# Disaster Recovery Guide

## Recovery Order

**ALWAYS restore in this sequence:**

```
1. Base (Traefik + Portainer)
2. Database Layer (PostgreSQL + Redis)
3. SSO (Authentik)
4. Monitoring (optional, restore after critical services)
5. All other stacks
```

## Full Recovery (Fresh Host)

### Step 1 — Provision host
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# For CN environments
sudo bash scripts/setup-cn-mirrors.sh
```

### Step 2 — Clone and configure
```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack
cp .env.example .env
nano .env  # Restore your original values
```

### Step 3 — Start base infra
```bash
cd stacks/base && docker compose up -d
cd ../databases && docker compose up -d
# Wait for healthy
docker compose ps
```

### Step 4 — Restore database volumes
```bash
# List available backups
bash scripts/backup.sh --list

# Restore specific backup
docker run --rm \
  -v databases_postgres_data:/restore \
  -v /backups:/backup:ro \
  alpine sh -c "cd /restore && tar xzf /backup/databases_YYYYMMDD.tar.gz --strip=2"

# Restart databases
cd stacks/databases && docker compose restart
```

### Step 5 — Start remaining stacks
```bash
for stack in sso monitoring ai; do
  cd stacks/$stack && docker compose up -d && cd ../..
done
```

### Step 6 — Verify
```bash
bash scripts/health-check.sh
```

## RTO Estimates

| Service tier | Expected recovery time |
|-------------|----------------------|
| Base + DB + SSO | ~15 minutes |
| All stacks | ~30 minutes |
| Full with data restore | ~1 hour |

## Verification Checklist

- [ ] All containers healthy (`docker compose ps`)
- [ ] Traefik dashboard reachable
- [ ] Authentik login works
- [ ] pgAdmin connects to PostgreSQL
- [ ] Grafana shows metrics
- [ ] Test notification via ntfy
