# Testing Stack

Automated testing infrastructure for the homelab — GitHub Actions self-hosted
runner with Docker-in-Docker (DinD) support, plus a test automation container
that runs scheduled validation scripts.

## What's Included

| Service | Version | Purpose |
|---------|---------|---------|
| GitHub Actions Runner | actions/runner:latest | Self-hosted CI/CD runner with DinD |
| Test Automation | docker:27-cli | Runs validation/health scripts |

## Architecture

```
GitHub Actions
    │
    │  Workflow_dispatch / Cron trigger
    ▼
GitHub → GH Runner (gh-runner) ←─── PAT auth (GH_RUNNER_TOKEN)
    │
    ├──► docker:latest (DinD sidecar)
    │
    └──► Runs workflow jobs:
          ├── docker compose config     (syntax validation)
          ├── docker compose up -d      (deploy)
          ├── scripts/test-backup.sh    (backup/restore)
          └── scripts/health-check.sh   (service health)

Test Automation (test-automation)
    │
    └──► Scheduled runs every 6h:
          ├── validate-stacks.sh  (all stacks)
          ├── health-check.sh     (all services)
          └── results → ./results/
```

## Quick Start

```bash
cd stacks/testing

# 1. Copy environment file and fill in values
cp .env.example .env
$EDITOR .env   # fill in GH_RUNNER_TOKEN, GH_RUNNER_REPO

# 2. Ensure the proxy network exists
docker network create proxy 2>/dev/null || true

# 3. Mount your homelab-stack repo (or clone it)
#    The STACKS_PATH env var should point to your homelab-stack directory.
#    Example (if running from repo root):
#    STACKS_PATH=/home/user/homelab-stack docker compose up -d

# 4. Start the stack
docker compose up -d

# 5. Verify runner is connected
#    Go to: https://github.com/YOUR_ORG/YOUR_REPO/settings/actions/runners
#    You should see "homelab-test-runner" (or your custom name) online.
```

## GitHub Workflow Example

Once the runner is registered, create `.github/workflows/homelab-test.yml`
in your homelab-stack repo:

```yaml
name: Homelab Stack Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 */6 * * *'   # Every 6 hours

jobs:
  validate-stacks:
    runs-on: self-hosted
    steps:
      - name: Checkout stacks
        uses: actions/checkout@v4

      - name: Validate all docker-compose files
        run: |
          for stack in stacks/*/docker-compose.yml; do
            echo "=== Validating $stack ==="
            docker compose -f "$stack" config --quiet \
              && echo "OK: $stack" \
              || { echo "FAIL: $stack"; exit 1; }
          done

  test-backup:
    runs-on: self-hosted
    steps:
      - name: Checkout stacks
        uses: actions/checkout@v4

      - name: Run backup test
        run: docker compose -f stacks/testing/docker-compose.yml exec test-automation bash /scripts/test-backup.sh

  health-check:
    runs-on: self-hosted
    steps:
      - name: Run health check
        run: docker compose -f stacks/testing/docker-compose.yml exec test-automation bash /scripts/health-check.sh
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GH_RUNNER_TOKEN` | ✅ | — | GitHub PAT with `repo` scope |
| `GH_RUNNER_REPO` | ✅ | — | Full repo URL, e.g. `https://github.com/illbnm/homelab-stack` |
| `GH_RUNNER_NAME` | — | `homelab-test-runner` | Display name in GitHub |
| `STACKS_PATH` | — | `.` | Path to homelab-stack repo on host |
| `TZ` | — | `Asia/Shanghai` | Container timezone |
| `REGION` | — | `CN` | Region for network-aware tests |

### GitHub PAT Requirements

The token needs at minimum:
- **`repo`** scope for private repositories
- **`public_repo`** scope for public repositories only

Create at: https://github.com/settings/tokens

## Scripts

### validate-stacks.sh

Validates all `docker-compose.yml` files in the `stacks/` directory using
`docker compose config --quiet`. Exits 0 if all are valid.

```bash
# Run manually
docker exec test-automation bash /scripts/validate-stacks.sh

# View last results
cat results/validate-stacks.log
```

### test-backup.sh

Tests the backup/restore cycle by:
1. Creating a test file with known content
2. Backing it up (via configured backup mechanism)
3. Deleting the file
4. Restoring from backup
5. Verifying content matches

```bash
# Run manually
docker exec test-automation bash /scripts/test-backup.sh

# View last results
cat results/backup-test.log
```

### health-check.sh

Checks that all services defined across all stacks are healthy by:
1. Reading all `docker-compose.yml` files in `stacks/`
2. Extracting service names
3. Running `docker inspect` on each service container
4. Reporting UP/ DOWN status

```bash
# Run manually
docker exec test-automation bash /scripts/health-check.sh

# View last results
cat results/health-check.log
```

## Troubleshooting

### Runner not appearing in GitHub

```bash
# Check runner logs
docker compose logs gh-runner

# Common issues:
# - GH_RUNNER_TOKEN is expired or revoked → regenerate
# - GH_RUNNER_TOKEN is missing 'repo' scope → needs repo scope
# - GH_RUNNER_REPO URL is incorrect → must be the full URL
```

### Test automation failing with "command not found: docker"

```bash
# The docker socket must be mounted correctly
docker compose exec test-automation docker version

# If this fails, check that /var/run/docker.sock is mounted on host
```

### validate-stacks.sh reports syntax errors

```bash
# Run with verbose output
docker exec test-automation bash -x /scripts/validate-stacks.sh

# Check the specific error
docker exec test-automation docker compose -f /stacks/STACK/docker-compose.yml config
```
