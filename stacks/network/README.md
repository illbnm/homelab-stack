# 🌐 Network Stack

AdGuard Home · WireGuard Easy · Cloudflare DDNS · Unbound · Nginx Proxy Manager

## Quick Start

```bash
# 1. Free port 53 (if systemd-resolved is occupying it)
chmod +x scripts/fix-dns-port.sh
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply

# 2. Configure environment
cp .env.example .env
# Edit .env with your domain, WireGuard host, Cloudflare token, etc.

# 3. Add Cloudflare API token
mkdir -p secrets
echo "your_cf_api_token_here" > secrets/cf_api_token
chmod 600 secrets/cf_api_token

# 4. Start
docker compose up -d
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| AdGuard Home | `3000` (admin) · `53` (DNS) | DNS filtering & ad blocking |
| WireGuard Easy | `51820/udp` · `51821` (UI) | VPN with web management |
| Cloudflare DDNS | host network | Auto-update DNS records |
| Unbound | internal only | Recursive DNS resolver |
| Nginx Proxy Manager | `81` (admin) · `3080` · `3443` | Alternative reverse proxy |

## Router DNS Configuration

To make AdGuard Home your network DNS:

1. **Find your router gateway IP** (e.g. `192.168.1.1`)
2. **Log into router admin** → DHCP / DNS settings
3. **Set primary DNS** to the machine running this stack (e.g. `192.168.1.100`)
4. **Set secondary DNS** to a public DNS as fallback (e.g. `1.1.1.1`)
5. **Reconnect devices** or flush DNS cache

## WireGuard Split Tunneling

By default, all traffic routes through VPN. For split tunneling:

1. Edit `.env`: `WG_ALLOWED_IPS=10.0.0.0/8,192.168.0.0/16`
2. Only local network traffic goes through VPN; internet traffic bypasses it

## Cloudflare DDNS

Supports multiple domains and IPv4/IPv6 dual-stack:

```env
CF_DOMAINS=example.com, *.example.com, homelab.example.com
CF_PROXIED=true
```

## Restoring systemd-resolved

If you need to undo the port 53 fix:

```bash
sudo ./scripts/fix-dns-port.sh --restore
```
