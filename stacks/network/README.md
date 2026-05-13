# Network Stack

Home networking infrastructure: DNS filtering, VPN access, and dynamic DNS updates.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | v0.107.52 | `adguard.<DOMAIN>` | DNS filtering + ad blocking |
| WireGuard Easy | 14 | `wg.<DOMAIN>` | VPN server with web UI |
| Cloudflare DDNS | 1.14.0 | — | Dynamic DNS for Cloudflare |
| Unbound | 1.21.1 | — | Recursive DNS resolver |

## Architecture

```
Internet
    │
    ▼
[Cloudflare DDNS]  →  Keeps DNS records in sync with your public IP

Clients (mobile, laptop)
    │
    ▼
[WireGuard Easy :51820/UDP]
    │  VPN tunnel established
    │  DNS routed to →
    │
    ▼
[AdGuard Home :53]
    │  DNS filtering, ad blocking
    │  Upstream DNS →
    │
    ▼
[Unbound :5353]  →  Recursive resolver (DNSCrypt fallback)
```

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Base stack (Traefik) deployed and running
- Cloudflare account with an API token having `Zone.DNS` edit permission
- Ports 53/UDP+TCP, 51820/UDP open on your firewall
- A domain managed on Cloudflare

## Quick Start

```bash
# 1. Link environment file
cd stacks/network
cp .env.example .env

# 2. Edit .env — at minimum set:
#    - DOMAIN
#    - WG_HOST (public domain/IP for WireGuard)
#    - WG_PASSWORD
#    - CF_TOKEN (Cloudflare API token)
#    - CF_ZONE_NAMES

# 3. Fix port 53 conflict (Linux with systemd-resolved)
bash ../../scripts/fix-dns-port.sh --check
bash ../../scripts/fix-dns-port.sh --apply

# 4. Start services
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `WG_HOST` | ✅ | Public WireGuard hostname/IP, e.g. `wg.example.com` |
| `WG_PASSWORD` | ✅ | Password for WireGuard Easy web UI |
| `CF_TOKEN` | ✅ | Cloudflare API token (Zone.DNS edit) |
| `CF_ZONE_NAMES` | ✅ | Comma-separated zone names, e.g. `example.com` |
| `CF_RECORD_NAMES` | — | Record names to update (default: `@`) |
| `CF_IP_VERSIONS` | — | `ipv4`, `ipv6`, or `ipv4,ipv6` (default: `ipv4,ipv6`) |
| `CF_RECORD_PROXIED` | — | `true` to proxy through Cloudflare CDN |
| `PORT_AGUARD_WORKER` | — | AdGuard Home web UI port (default: `3000`) |
| `PORT_WG_EASY` | — | WireGuard UDP port (default: `51820`) |
| `PORT_WG_DASHBOARD` | — | WireGuard web UI port (default: `51821`) |
| `WG_DEFAULT_ROUTE` | — | Client routing: `0.0.0.0/0` for full, subnet for split |
| `WG_MTU` | — | MTU value for WireGuard (default: `1420`) |

### Fix DNS Port Conflicts (Linux)

On Linux hosts with `systemd-resolved`, port 53 is often occupied:

```bash
# Check status
./scripts/fix-dns-port.sh --check

# Apply fix (disables resolved stub listener)
./scripts/fix-dns-port.sh --apply

# Restore resolved stub listener
./scripts/fix-dns-port.sh --restore
```

### WireGuard — Split Tunneling

To route only specific subnets through the VPN (instead of all traffic):

```bash
# In .env, set WG_DEFAULT_ROUTE to your LAN subnets, comma-separated:
WG_DEFAULT_ROUTE=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

### AdGuard Home — DNS Filter Lists

After first launch, open the AdGuard Home web UI at `adguard.<DOMAIN>` and:
1. Go to **Filters → DNS Blocklists**
2. Add filter lists (examples included below)
3. Set upstream DNS to `127.0.0.1#5353` (Unbound) or external DoH/DoT

Recommended filter lists:
```
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt
https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt
```

### Cloudflare DDNS — Configuration

The Cloudflare DDNS container automatically detects your public IP and updates
Cloudflare DNS records. Configure in `.env`:

```bash
# Single domain
CF_ZONE_NAMES=example.com

# Multiple domains
CF_ZONE_NAMES=example.com,example.net

# Update specific subdomain
CF_RECORD_NAMES=myserver

# Both IPv4 and IPv6
CF_IP_VERSIONS=ipv4,ipv6
```

### Router DNS Configuration

Point your router's DNS settings to the homelab server's IP address so all
LAN devices route DNS through AdGuard Home:

1. Log into your router admin panel
2. Navigate to **DHCP / DNS settings**
3. Set primary DNS to your homelab server IP (e.g. `192.168.1.100`)
4. Leave secondary DNS blank or set a backup (e.g. `1.1.1.1`)
5. Save and reboot clients

### Router WireGuard Client (Optional)

Some routers support WireGuard natively. Configure your router to connect as
a WireGuard client using:
- **Endpoint**: `WG_HOST:51820`
- **Private Key**: Generate from the WireGuard Easy web UI
- **DNS**: Your homelab server's internal IP

This allows all router-connected devices to pass through the VPN automatically.

## Troubleshooting

### AdGuard Home port 53 bind fails
Run `scripts/fix-dns-port.sh --apply` to disable systemd-resolved stub listener.

### WireGuard clients can't reach internal services
- Verify `net.ipv4.ip_forward=1` is set on the host
- Check that iptables MASQUERADE rules are applied (WG_POST_UP)
- Ensure AdGuard Hosts upstream DNS is not set to `127.0.0.1` (use server IP)

### Cloudflare DDNS not updating
- Verify `CF_TOKEN` has `Zone.DNS` edit permission
- Check container logs: `docker compose logs cloudflare-ddns`
- Ensure the domain is hosted on Cloudflare

## Service URLs

| Service | URL |
|---------|-----|
| AdGuard Home | `https://adguard.${DOMAIN}` |
| WireGuard Easy | `https://wg.${DOMAIN}` |
