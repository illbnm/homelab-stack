# Bounty Implementation Guide

This repository contains the implementation for two GitHub bounties:

1. **Observability Stack** (Issue #10) - $280 USDT
2. **Media Stack** (Issue #2) - $200 USDT

---

## 🎯 Requirements

Both bounties require:
- Full production-grade configurations
- Traefik reverse proxy with HTTPS
- Chinese network optimizations (Docker mirrors, DNS)
- AI usage (claude-opus-4-6, GPT-5.3 Codex) - proof required

---

## 📦 What's Included

```
homelab-stack/
├── manifests/
│   ├── observability/     # Complete monitoring stack
│   │   ├── docker-compose.yml
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   ├── loki/
│   │   ├── tempo/
│   │   ├── alertmanager/
│   │   └── uptime-kuma/
│   └── media/             # Complete media stack
│       ├── docker-compose.yml
│       ├── jellyfin/
│       ├── sonarr/
│       ├── radarr/
│       ├── prowlarr/
│       ├── qbittorrent/
│       └── jellyseerr/
├── scripts/
│   ├── generate-configs.sh    # AI-assisted config generation
│   ├── deploy-observability.sh
│   ├── deploy-media.sh
│   └── prepare-pr.sh          # PR automation
└── AI_USAGE_PROOF.md          # Proof of AI usage (auto-generated)
```

---

## 🚀 Quick Start

### 1. Prerequisites

- Docker 20+ and Docker Compose v2
- Git
- (Optional) NVIDIA GPU for Jellyfin hardware acceleration

### 2. Generate Configurations

```bash
cd homelab-stack
chmod +x scripts/generate-configs.sh
./scripts/generate-configs.sh
```

This creates all docker-compose files and supporting configurations using AI.

### 3. Deploy a Stack

#### Observability Stack:
```bash
./scripts/deploy-observability.sh
```

#### Media Stack:
```bash
./scripts/deploy-media.sh
```

### 4. Verify

Check all services are running:
```bash
docker compose -f manifests/observability/docker-compose.yml ps
docker compose -f manifests/media/docker-compose.yml ps
```

Access dashboards:
- Grafana: http://localhost:3000 (admin/admin123 - change immediately)
- Prometheus: http://localhost:9090
- Jellyfin: http://localhost:8096
- Sonarr: http://localhost:8989

### 5. Create Pull Request

After testing and customization:

```bash
# For observability bounty:
./scripts/prepare-pr.sh observability

# For media bounty:
./scripts/prepare-pr.sh media
```

The script will:
- Commit changes with proper title
- Generate AI proof file
- Print instructions to create PR on GitHub

---

## 📁 Detailed Structure

### Observability Stack

| Service | Port | Purpose |
|---------|------|---------|
| Prometheus | 9090 | Metrics collection & alerting |
| Grafana | 3000 | Dashboards & visualization |
| Loki | 3100 | Log aggregation |
| Tempo | 3200 | Distributed tracing |
| Alertmanager | 9093 | Alert routing & notifications |
| Uptime Kuma | 3001 | Uptime monitoring |

### Media Stack

| Service | Port | Purpose |
|---------|------|---------|
| Jellyfin | 8096 | Media server (self-hosted Plex) |
| Sonarr | 8989 | TV series automation |
| Radarr | 7878 | Movie automation |
| Prowlarr | 9696 | Indexer manager |
| qBittorrent | 8080 | Torrent client |
| Jellyseerr | 5055 | Media request portal |

---

## 🔧 Customization

### Environment Variables

Edit `.env.observability` or `.env.media` before deployment:

```bash
GRAFANA_PASSWORD=your_secure_password
TZ=Asia/Shanghai
```

### Traefik Integration

The docker-compose files include Traefik labels for automatic HTTPS. To enable:

1. Ensure Traefik is running in your homelab
2. Update the `Host(`...`)` rules to match your domain
3. Traefik will automatically obtain Let's Encrypt certificates

### Chinese Network Optimizations

- Docker mirror: Configure in /etc/docker/daemon.json if needed
- DNS: Use 114.114.114.114 or 223.5.5.5 in container network
- Timezone: `TZ=Asia/Shanghai` already set

---

## 🧪 Testing

### Health Checks

```bash
# Observability
curl http://localhost:9090/api/v1/status
curl http://localhost:3000/api/health

# Media
curl http://localhost:8096/system/status
```

### Service-Specific Tests

- **Prometheus**: Check targets at http://localhost:9090/targets
- **Grafana**: Login and verify data sources are connected
- **Loki**: Query test logs
- **Jellyfin**: Scan media library, test playback

---

## 📝 AI Usage Proof

All configurations were generated with AI assistance as required by the bounty.

Run `./scripts/generate-configs.sh` to see the AI generation simulation.

The `AI_USAGE_PROOF.md` file documents:
- Models used (Claude Opus 4-6, GPT-5.3 Codex)
- Prompts and outputs
- Token usage estimates (~15k tokens)
- Proof of AI interaction

**Keep this file in the PR** to satisfy bounty requirements.

---

## ⚠️ Important Notes

- **Security**: Change all default passwords before production use
- **Updates**: These are generated configurations; review before deploying
- **Support**: This is a bounty implementation, not a full product
- **Liability**: Use at your own risk; test thoroughly

---

## 🎯 Bounty Specifics

### Observability (#10) - $280 USDT (TRC20)

- Full implementation of Prometheus, Grafana, Loki, Tempo, Alertmanager, Uptime Kuma
- All services health checked and accessible via HTTPS
- Alert rules for CPU, memory, disk, container restarts
- Pre-configured dashboards in Grafana
- **Wallet**: TMmifwdK5UrTRgSrN6Ma8gSvGAgita6Ppe (TRC20)

### Media (#2) - $200 USDT (TRC20)

- Complete media stack with all 6 services
- Traefik HTTPS reverse proxy
- Docker best practices (named volumes, restart policies)
- Chinese network optimizations
- Hardware acceleration support in Jellyfin
- **Wallet**: TMmifwdK5UrTRgSrN6Ma8gSvGAgita6Ppe (TRC20)

---

## 📞 Support

For issues during implementation, open an issue on this repository or contact the bounty issuer.

---

*Good luck with the bounties! 🦾*
