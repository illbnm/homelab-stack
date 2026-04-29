# Network Stack

Home network infrastructure: DNS ad-blocking, VPN access, and dynamic DNS.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Unbound | 1.21.1 | *(internal)* | Recursive DNS resolver |
| AdGuard Home | v0.107.52 | `adguard.<DOMAIN>` | DNS filtering + ad blocking |
| WireGuard Easy | 14 | `vpn.<DOMAIN>` | VPN server with Web UI |
| Cloudflare DDNS | 1.14.0 | *(background)* | Dynamic DNS updater |

## Architecture

```
Internet
    │
    ▼
[Cloudflare DDNS] ──updates──► CF DNS records (keeps domain pointing to your IP)
    │
    ▼
[AdGuard Home :53] ──upstream──► [Unbound] ──recursive──► Root DNS servers
    │
    ├── DNS filtering / ad blocking for entire LAN
    │
    ▼
[WireGuard Easy :51820/udp] ──DNS──► AdGuard Home
    │
    └── VPN clients use AdGuard as DNS (ad blocking on VPN too)
```

## Prerequisites

- Base stack running (Traefik on `proxy` network)
- Port 53 available (see `fix-dns-port.sh` below)
- Port 51820/udp open on your firewall (for WireGuard)
- A Cloudflare account with API token (for DDNS)

## Quick Start

```bash
cd stacks/network

# Step 1: Free port 53 if systemd-resolved is using it
sudo ./fix-dns-port.sh --check     # Check status
sudo ./fix-dns-port.sh --apply     # Fix if needed

# Step 2: Configure environment
cp .env.example .env
vim .env  # Set WG_HOST, WG_PASSWORD, CF_API_TOKEN, CF_DOMAINS

# Step 3: Symlink shared .env (or use local)
# ln -sf ../../.env .env

# Step 4: Start services
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TZ` | ✅ | `Asia/Shanghai` | Timezone |
| `DOMAIN` | ✅ | — | Base domain |
| `WG_HOST` | ✅ | — | Public IP or domain for VPN clients |
| `WG_PASSWORD` | ✅ | — | WireGuard Web UI password |
| `WG_PORT` | — | `51820` | WireGuard UDP port |
| `CF_API_TOKEN` | ✅ | — | Cloudflare API token |
| `CF_DOMAINS` | ✅ | — | Domains to update (comma-separated) |
| `CF_RECORD_TYPE` | — | `A` | Record type: `A`, `AAAA`, or `A,AAAA` |
| `CF_PROXIED` | — | `false` | Enable Cloudflare proxy (orange cloud) |

### Service URLs

| Service | URL |
|---------|-----|
| AdGuard Home | `https://adguard.<DOMAIN>` |
| WireGuard Easy | `https://vpn.<DOMAIN>` |

## Post-Deploy Setup

### 1. AdGuard Home — Initial Setup

1. Open `https://adguard.<DOMAIN>` (or `http://<server-ip>:3000` for first-time setup)
2. Set admin username and password
3. Configure upstream DNS:
   - Go to **Settings → DNS Settings → Upstream DNS servers**
   - Set to `unbound:53` (uses the internal Unbound resolver)
   - Alternative: `1.1.1.1`, `8.8.8.8` for external resolvers
4. Add filter lists:
   - Go to **Filters → DNS blocklists → Add blocklist**
   - Recommended: "AdGuard DNS filter", "EasyList", "OISD Big"

### 2. Router DNS Configuration

Point your router's DNS to the AdGuard Home server:

```
Primary DNS:   <server-ip>  (AdGuard Home)
Secondary DNS: (leave blank or use 1.1.1.1 as fallback)
```

All devices on your LAN will now use AdGuard for DNS + ad filtering.

### 3. WireGuard Easy — Add Clients

1. Open `https://vpn.<DOMAIN>`
2. Log in with `WG_PASSWORD`
3. Click **+ New Client**
4. Scan the QR code or download the `.conf` file
5. Import into WireGuard app (iOS/Android/macOS/Windows)

**DNS**: Clients automatically use `adguardhome` as DNS, so VPN traffic also gets ad filtering.

### 4. Cloudflare DDNS

1. Create API token at: https://dash.cloudflare.com/profile/api-tokens
   - Template: "Edit zone DNS"
   - Zone: select your domain
2. Set `CF_API_TOKEN` in `.env`
3. Set `CF_DOMAINS` to the domains that need dynamic updates
   - Example: `home.example.com` or `*.home.example.com`
4. For dual-stack (IPv4 + IPv6):
   ```env
   CF_RECORD_TYPE=A,AAAA
   IP4_POLICY=cloudflare
   IP6_POLICY=cloudflare
   ```

## fix-dns-port.sh

On most Linux distros, `systemd-resolved` binds to port 53, blocking AdGuard Home.

```bash
# Check if port 53 is occupied
sudo ./fix-dns-port.sh --check

# Free port 53 by disabling systemd-resolved stub listener
sudo ./fix-dns-port.sh --apply

# Restore original config (re-enable systemd-resolved stub listener)
sudo ./fix-dns-port.sh --restore
```

**What `--apply` does**:
1. Backs up `/etc/systemd/resolved.conf`
2. Sets `DNSStubListener=no`
3. Restarts `systemd-resolved`
4. Updates `/etc/resolv.conf` symlink

## Split Tunneling (WireGuard)

By default, WireGuard Easy routes **all** traffic through the VPN. For split tunneling (only specific subnets through VPN):

1. In WireGuard Easy, edit a client's config
2. Change `AllowedIPs` from `0.0.0.0/0, ::/0` to:
   - **Access home network only**: `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`
   - **Access specific subnet**: `192.168.1.0/24`
3. Save and reconnect the client

## Startup Order

```
unbound (healthy) ──► adguardhome (healthy) ──► wg-easy (healthy)
cloudflare-ddns (independent, starts in parallel)
```

## CN Network Adaptation

The `ghcr.io` images (wg-easy, cloudflare-ddns) may be slow in China. Set up Docker mirror:

```bash
# From repo root
./scripts/setup-cn-mirrors.sh
```

Alternative images:
- `ghcr.io/wg-easy/wg-easy:14` → configure Docker mirror in `/etc/docker/daemon.json`
- `mvance/unbound:1.21.1` → available on Docker Hub (no special mirror needed)

## Troubleshooting

### "Port 53 already in use"
```bash
sudo ./fix-dns-port.sh --check
sudo ./fix-dns-port.sh --apply
```

### WireGuard clients can't connect
- Verify port `51820/udp` is open on your firewall/router
- Check `WG_HOST` is set to your public IP (not private IP)
- Test: `nc -zvu <your-public-ip> 51820`

### AdGuard Home not filtering ads
- Check upstream DNS is set to `unbound:53` in AdGuard settings
- Verify filter lists are enabled: **Filters → DNS blocklists**
- Flush DNS cache on client: `sudo resolvectl flush-caches` (Linux) or `ipconfig /flushdns` (Windows)

### Cloudflare DDNS not updating
- Verify `CF_API_TOKEN` has DNS edit permission for the correct zone
- Check logs: `docker compose logs cloudflare-ddns`
- Test manually: set `QUIET=false` and check output

## Optional: Authentik Forward Auth

To protect AdGuard Home or WireGuard Easy with SSO:

```yaml
- "traefik.http.routers.adguard.middlewares=authentik@file,security-headers@file"
```

Note: WireGuard's Web UI is typically access-restricted by its own password, so Forward Auth is optional.
