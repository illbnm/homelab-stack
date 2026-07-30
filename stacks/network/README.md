# Network Stack

Self-hosted network infrastructure: DNS filtering, VPN access, dynamic DNS, and recursive DNS resolver.

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| AdGuard Home | `adguard/adguardhome:v0.107.52` | 53/udp, 53/tcp | `https://dns.${DOMAIN}` |
| WireGuard Easy | `ghcr.io/wg-easy/wg-easy:14` | 51820/udp | `https://vpn.${DOMAIN}` |
| Cloudflare DDNS | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | — | Background service |
| Unbound | `mvance/unbound:1.21.1` | 5335/udp | Internal resolver |

## Quick Start

```bash
# 1. Fix port 53 conflict (if systemd-resolved is running)
sudo bash ../scripts/fix-dns-port.sh --check
sudo bash ../scripts/fix-dns-port.sh --apply

# 2. Copy and edit environment variables
cp .env.example .env
nano .env

# 3. Start the network stack
docker compose up -d
```

## DNS Setup

### AdGuard Home Configuration

After first start, AdGuard Home runs a setup wizard at `http://<server-ip>:3000`.

**Recommended upstream DNS (Unbound):**
```
127.0.0.1:5335
```

**Alternative upstream (DoH):**
```
https://dns.cloudflare.com/dns-query
https://dns.google/dns-query
```

**Filtering lists (add in Settings → DNS → Filters):**
- AdGuard Base: `https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt`
- EasyList: `https://easylist.to/easylist/easylist.txt`
- EasyPrivacy: `https://easylist.to/easylist/easyprivacy.txt`
- OISD Blocklist: `https://big.oisd.nl`

### Router DNS Configuration

Point your router's DNS to the AdGuard Home server:

**Option 1 — DHCP DNS:**
- Set primary DNS: `<server-ip>`
- Set secondary DNS: `1.1.1.1` (fallback)

**Option 2 — Per-device:**
- Configure each device's DNS to `<server-ip>`

**Option 3 — Pi-hole style:**
- Router advertises AdGuard Home as DNS via DHCP
- AdGuard Home resolves via Unbound (recursive)
- No external DNS dependency

## WireGuard VPN

### Setup
1. Access Web UI at `https://vpn.${DOMAIN}`
2. Login with password (hash set in `.env`)
3. Generate client QR codes with one click
4. Scan QR code with WireGuard mobile app

### Split Tunneling

By default, WireGuard routes ALL traffic through VPN. For split tunneling (only internal traffic):

**In the wg-easy Web UI:**
- Edit client → Allowed IPs: `10.0.0.0/8, 192.168.0.0/16`
- This routes only internal network traffic through VPN

**Manual config:**
```ini
[Interface]
Address = 10.8.0.2/24
DNS = 10.8.0.1  # AdGuard Home for DNS

[Peer]
AllowedIPs = 10.0.0.0/8, 192.168.0.0/16  # Internal only
```

### DNS Through VPN

WireGuard clients use AdGuard Home (10.8.0.1) for DNS, providing ad-blocking on mobile devices too.

## Cloudflare DDNS

### Prerequisites
1. Cloudflare account with your domain
2. API token with `Zone.DNS:Edit` permission
3. DNS records already created in Cloudflare

### Configuration
```bash
# .env
CF_API_TOKEN=your_token_here
DDNS_DOMAINS=example.com,vpn.example.com,cloud.example.com
DDNS_CRON=@every 5m
```

### IPv6 Support

The DDNS service supports dual-stack (IPv4 + IPv6) automatically. Ensure your server has IPv6 connectivity.

## Port 53 Conflict (systemd-resolved)

Many Linux distributions run `systemd-resolved` which binds port 53 by default.

```bash
# Check if port 53 is occupied
sudo bash scripts/fix-dns-port.sh --check

# Disable systemd-resolved stub listener
sudo bash scripts/fix-dns-port.sh --apply

# Restore (re-enable systemd-resolved)
sudo bash scripts/fix-dns-port.sh --restore
```

The script:
- Detects what's using port 53
- Backs up `/etc/systemd/resolved.conf`
- Sets `DNSStubListener=no`
- Updates `/etc/resolv.conf` with fallback DNS
- Verifies port 53 is freed

## Firewall Configuration

```bash
# DNS (AdGuard Home)
sudo ufw allow 53/udp
sudo ufw allow 53/tcp

# WireGuard VPN
sudo ufw allow 51820/udp

# AdGuard Web UI (if not using Traefik)
sudo ufw allow 3000/tcp
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DOMAIN` | Your root domain |
| `WG_PASSWORD_HASH` | WireGuard admin password hash |
| `CF_API_TOKEN` | Cloudflare API token |
| `DDNS_DOMAINS` | Comma-separated domains for DDNS |
| `DDNS_CRON` | Update schedule (default: every 5m) |
| `TZ` | Timezone |

## Health Checks

```bash
# DNS resolution test
dig @<server-ip> google.com

# AdGuard Home status
curl -s http://<server-ip>:3000/

# Unbound health
dig @<server-ip> -p 5335 example.com

# WireGuard status
docker logs wg-easy --tail 20
```