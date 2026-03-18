## Network Stack Implementation

Implements **Bounty #4: Network Stack ($140 USDT)**

### Services (4 containers)

| Service | Image | Description |
|---------|-------|-----------|
| AdGuard Home | adguard/adguardhome:v0.107.52 | DNS filtering + ad blocking |
| Unbound | mvance/unbound:1.21.1 | Recursive DNS resolver |
| WireGuard Easy | ghcr.io/wg-easy/wg-easy:14 | VPN with Web UI |
| Cloudflare DDNS | ghcr.io/favonia/cloudflare-ddns:1.14.0 | Dynamic DNS |

### Files Added/Modified

- `docker-compose.yml` — 4 services with health checks, Traefik labels, proper capabilities
- `unbound.conf` — Recursive DNS with DNSSEC, QNAME minimization, aggressive caching
- `scripts/fix-dns-port.sh` — Handles systemd-resolved port 53 conflict (--check, --apply, --restore)
- `.env.example` — All configurable variables documented
- `README.md` — Full docs: architecture, DNS chain, WireGuard config, split tunneling, router setup, troubleshooting

### Acceptance Criteria

- [x] AdGuard Home DNS resolution with ad filtering
- [x] WireGuard VPN with Web UI and QR code generation
- [x] Cloudflare DDNS with IPv4+IPv6 support
- [x] fix-dns-port.sh handles systemd-resolved conflict
- [x] README includes router DNS configuration guide
- [x] Unbound recursive resolver (privacy-focused, no upstream DNS provider)
- [x] No hardcoded secrets

Generated/reviewed with: claude-opus-4-6
