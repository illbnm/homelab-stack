# Network Stack

Home network infrastructure: DNS filtering, recursive resolution, VPN access, and dynamic DNS.

## Architecture

```
Internet
  │
  ├─► Cloudflare DDNS ──► Updates DNS records
  │
  ▼
Router (port forward 51820/UDP → WireGuard)
  │
  ├─► Port 53 ──► AdGuard Home ──► Unbound (recursive DNS)
  │
Traefik (base stack)
  │
  ├─► dns.${DOMAIN}   → AdGuard Home  (DNS admin UI)
  └─► vpn.${DOMAIN}   → WireGuard Easy (VPN admin UI)
```

## Services

| Service | Version | Ports | Description |
|---------|---------|-------|-------------|
| AdGuard Home | v0.107.52 | 53/TCP+UDP, 3000 | DNS filtering + ad blocking |
| Unbound | 1.21.1 | - (internal) | Recursive DNS resolver |
| WireGuard Easy | 14 | 51820/UDP, 51821 | VPN server with Web UI |
| Cloudflare DDNS | 1.14.0 | - | Dynamic DNS updater |

## Quick Start

```bash
# 1. Fix port 53 conflict (Linux with systemd-resolved)
sudo bash scripts/fix-dns-port.sh --check
sudo bash scripts/fix-dns-port.sh --apply

# 2. Configure environment
cp .env.example .env
nano .env

# 3. Generate WireGuard password hash
docker run -it ghcr.io/wg-easy/wg-easy wgpw 'YOUR_PASSWORD'
# Copy the hash to WG_PASSWORD_HASH in .env

# 4. Start all services
docker compose up -d

# 5. Check health
docker compose ps
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `example.com` | Base domain for Traefik routing |
| `TZ` | `Asia/Shanghai` | Timezone |
| `WG_HOST` | - | Public hostname/IP for WireGuard |
| `WG_PASSWORD_HASH` | - | Bcrypt hash for WG-Easy web UI |
| `WG_DNS` | `10.8.0.1` | DNS server for VPN clients |
| `WG_ALLOWED_IPS` | `0.0.0.0/0, ::/0` | VPN routing (all or split) |
| `CF_API_TOKEN` | - | Cloudflare API token |
| `CF_DOMAINS` | - | Domains to update via DDNS |
| `CF_PROXIED` | `false` | Proxy through Cloudflare |

## DNS Resolution Chain

```
Client Query
  │
  ▼
AdGuard Home (53)
  ├── Filter lists (ads, tracking, malware)
  ├── Custom rules
  └── Forward to ↓
      │
      ▼
    Unbound (recursive)
      └── Queries root servers directly
          (no upstream DNS provider needed)
```

### Why Unbound?

- **Privacy**: No queries sent to Google/Cloudflare DNS
- **Security**: DNSSEC validation, QNAME minimization
- **Performance**: Aggressive caching with prefetch
- **Independence**: Resolve directly from root servers

## Post-Deploy Configuration

### 1. AdGuard Home

1. Open `dns.${DOMAIN}`, complete initial setup
2. **DNS Settings → Upstream DNS**:
   ```
   # Point to Unbound container
   unbound:53
   ```
3. **Filters → DNS Blocklists**: Add recommended lists:
   - AdGuard DNS filter
   - AdAway Default Blocklist
   - OISD Blocklist (full)
   - Steven Black's Hosts

### 2. WireGuard

1. Open `vpn.${DOMAIN}`, log in with your password
2. Click **"+ New Client"** to create a VPN profile
3. Scan the **QR code** with the WireGuard mobile app
4. Or download the `.conf` file for desktop clients

### 3. Router DNS Configuration

Point your router's DNS to the AdGuard Home server:

```
Primary DNS:   <server-ip>
Secondary DNS: <server-ip>  (or leave blank)
```

This ensures all devices on the network use AdGuard for DNS.

### 4. Cloudflare DDNS

1. Create a [Cloudflare API Token](https://dash.cloudflare.com/profile/api-tokens):
   - Permissions: Zone → DNS → Edit
   - Zone Resources: Include → Specific zone → your domain
2. Add the token to `.env` as `CF_API_TOKEN`
3. The container auto-updates DNS records every 5 minutes

## Split Tunneling (WireGuard)

To route only internal traffic through VPN (not all internet):

```env
# Route only LAN traffic through VPN
WG_ALLOWED_IPS=10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
```

For full tunnel (route everything):

```env
WG_ALLOWED_IPS=0.0.0.0/0, ::/0
```

## Port 53 Conflict (systemd-resolved)

On Ubuntu/Debian, `systemd-resolved` occupies port 53 by default. Use the included script:

```bash
# Check if port 53 is taken
sudo bash scripts/fix-dns-port.sh --check

# Apply fix (disables stub listener, backs up config)
sudo bash scripts/fix-dns-port.sh --apply

# Restore original config if needed
sudo bash scripts/fix-dns-port.sh --restore
```

## Authentik SSO Integration (Optional)

Protect AdGuard and WireGuard UIs with Authentik forward auth:

```yaml
# Add to service labels:
- traefik.http.routers.adguard.middlewares=authentik@docker
- traefik.http.routers.wireguard.middlewares=authentik@docker
```

## Troubleshooting

### DNS Not Resolving

```bash
# Test AdGuard directly
dig @localhost google.com

# Test Unbound
docker compose exec unbound drill @127.0.0.1 google.com

# Check AdGuard upstream config
curl http://localhost:3000/control/dns_info
```

### WireGuard Clients Can't Connect

1. Verify port forwarding: `51820/UDP` → server IP
2. Check firewall: `sudo ufw allow 51820/udp`
3. Verify WG_HOST matches your public IP/domain

### Cloudflare DDNS Not Updating

```bash
# Check container logs
docker compose logs cloudflare-ddns

# Verify API token permissions
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### CN Mirror Alternatives

```yaml
# AdGuard Home: No official CN mirror; pull directly
# WireGuard Easy: ghcr.io — use ghcr mirror or proxy
# Unbound: Docker Hub — configure registry mirror
# Cloudflare DDNS: ghcr.io — use ghcr mirror or proxy
```

---

Generated/reviewed with: claude-opus-4-6
