# Robustness Stack — Environment Hardening & CN Network Adaptation

**Bounty:** #8 — Robustness & CN Network ($250)

## Purpose

Makes HomeLab Stack deployable in any network environment, with full support for mainland China network conditions.

## Scripts

All scripts are located in the project root `scripts/` directory:

| Script | Purpose | Status |
|--------|---------|--------|
| `scripts/check-connectivity.sh` | Network reachability diagnostics | Included in master |
| `scripts/setup-cn-mirrors.sh` | Configure Docker mirror accelerators | Included in master |
| `scripts/localize-images.sh` | Replace gcr.io/ghcr.io with CN mirrors | Included in master |
| `scripts/wait-healthy.sh` | Wait for containers to become healthy | Included in master |
| `scripts/diagnose.sh` | Full system diagnostics report | Included in master |
| `scripts/check-deps.sh` | Pre-flight dependency check | Included in master |
| `scripts/cn-pull.sh` | CN-aware image pull with mirror fallback | Included in master |

## Configuration

### CN Mirror Mapping

The file `config/cn-mirrors.yml` contains the complete mapping of foreign registries to CN-accessible mirrors.

```yaml
mirrors:
  gcr.io: m.daocloud.io/gcr.io
  ghcr.io: ghcr.m.daocloud.io
  quay.io: quay.m.daocloud.io
  docker.io: docker.m.daocloud.io
```

## Usage

```bash
# 1. Check if mirrors are needed
./scripts/check-connectivity.sh

# 2. If in China, setup Docker mirrors (requires sudo)
sudo ./scripts/setup-cn-mirrors.sh

# 3. Localize images in compose files
./scripts/localize-images.sh --cn

# 4. Verify all images can be pulled
./scripts/cn-pull.sh --verify
```

## Architecture

All scripts implement:
- Exponential backoff retry for network failures
- Auto-detection of CN network conditions
- Safe rollback (every operation is reversible)
- Detailed logging for debugging
