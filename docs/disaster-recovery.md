# Disaster Recovery Guide

## Recovery Time Objective (RTO)

| Service | RTO |
|---------|-----|
| Base (Traefik, Portainer) | 15 min |
| Database (PostgreSQL, Redis) | 30 min |
| SSO (Authentik) | 45 min |
| All other stacks | 2-4 hours |

## Recovery Order

### 1. Base Infrastructure
```bash
docker compose -f stacks/base/docker-compose.yml up -d
```

### 2. Database Layer
```bash
docker compose -f stacks/databases/docker-compose.yml up -d
```

### 3. SSO (Authentik)
```bash
docker compose -f stacks/sso/docker-compose.yml up -d
```

### 4. All Other Stacks
```bash
./scripts/stack-manager.sh --start-all
```

### 5. Restore Data
```bash
# From Duplicati web UI: https://backup.your-domain.com
# Or via restic:
restic -r rest:http://restic-server:8000/ snapshots
restic -r rest:http://restic-server:8000/ restore latest --target /
```

## Verify Recovery

1. All containers healthy: `./scripts/wait-healthy.sh`
2. SSO login works
3. Data integrity check via Duplicati
