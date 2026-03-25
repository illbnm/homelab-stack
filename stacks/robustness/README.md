# Robustness Stack

Infrastructure hardening and management tools for your homelab.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Dockge | `louislam/dockge:1.4.2` | 5001 | Docker Compose manager |
| Diun | `crazymax/diun:4.28.0` | - | Image update notifier |
| Autoheal | `willfarrell/autoheal:latest` | - | Auto-restart unhealthy |
| Ofelia | `mcuadros/ofelia:0.3.7` | - | Job scheduler |
| Flame | `pawelmalak/flame:2.3.1` | 5005 | Application dashboard |

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 2. Start Services

```bash
docker compose up -d
```

### 3. Access Services

| Service | URL |
|---------|-----|
| Flame Dashboard | https://home.yourdomain.com |
| Dockge | https://dockge.yourdomain.com |

## Service Details

### Dockge (Docker Compose Manager)

Web UI for managing Docker Compose stacks.

Features:
- Create/edit/delete stacks
- Real-time logs
- Terminal access
- Multi-host support

Usage:
1. Access https://dockge.yourdomain.com
2. Point to your stacks directory (`/opt/stacks`)
3. Manage all compose files

### Diun (Docker Image Update Notifier)

Monitors Docker images and sends notifications when updates are available.

Features:
- Check for image updates daily
- Notify via ntfy (or email, Slack, etc.)
- Only notify on actual changes

Configuration:
```yaml
# Labels to enable checking for specific containers
labels:
  - diun.enable=true
  - diun.watch_repo=true
```

### Autoheal

Automatically restarts unhealthy containers.

Configuration:
- `AUTOHEAL_INTERVAL`: Check interval in seconds (default: 5)
- `AUTOHEAL_START_PERIOD`: Grace period after start (default: 60)

Works with containers that have health checks defined.

### Ofelia

Cron-like job scheduler for Docker containers.

Features:
- Run jobs in containers
- Schedule with cron syntax
- No overlap option

Example jobs:
```yaml
labels:
  ofelia.job-local.backup.schedule: "0 0 2 * * *"
  ofelia.job-local.backup.command: "/scripts/backup.sh"
```

### Flame

Application dashboard for quick access to all services.

Features:
- Custom apps and bookmarks
- Docker integration (auto-discovery)
- Theming support

Configuration:
1. Access https://home.yourdomain.com
2. Login with password
3. Add apps and categories

## Health Monitoring

### Check All Containers

```bash
./scripts/healthcheck.sh
```

### With Notification

```bash
./scripts/healthcheck.sh --notify
```

### Cron Job

Add to crontab:
```bash
0 * * * * /path/to/healthcheck.sh --notify
```

## Job Examples

### Daily Backup

```yaml
labels:
  ofelia.job-local.backup.schedule: "0 0 2 * * *"
  ofelia.job-local.backup.command: "curl -sf http://backup-server/trigger"
```

### Weekly Cleanup

```yaml
labels:
  ofelia.job-local.cleanup.schedule: "0 0 3 * * 0"
  ofelia.job-local.cleanup.command: "find /logs -name '*.log' -mtime +30 -delete"
```

### Hourly Health Check

```yaml
labels:
  ofelia.job-local.health.schedule: "0 0 * * * *"
  ofelia.job-local.health.command: "curl -sf http://localhost:8080/health"
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Dockge | 64 MB | 128 MB |
| Diun | 32 MB | 64 MB |
| Autoheal | 16 MB | 32 MB |
| Ofelia | 16 MB | 32 MB |
| Flame | 32 MB | 64 MB |
| **Total** | **160 MB** | **320 MB** |

## Troubleshooting

### Dockge Can't Access Docker

```bash
# Check socket permissions
ls -la /var/run/docker.sock

# Add user to docker group
sudo usermod -aG docker $USER
```

### Diun Not Sending Notifications

```bash
# Check logs
docker logs diun

# Test ntfy connection
curl -sf http://ntfy:80/health
```

### Autoheal Not Working

```bash
# Check if containers have health checks
docker inspect --format='{{.State.Health.Status}}' <container>
```

### Ofelia Jobs Not Running

```bash
# Check logs
docker logs ofelia

# Verify labels
docker inspect --format='{{.Config.Labels}}' <container>
```

## License

MIT
