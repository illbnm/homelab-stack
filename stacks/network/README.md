# Network Stack -- AdGuard Home + Unbound + WireGuard (wg-easy)

## Network Diagram

```
  Internet/WAN
  |              |
  port 443       port 51820/udp
  |              |
  Traefik        WireGuard (wg-easy)
  (base stack)   VPN tunnel, 10.8.0.0/24
  |    |    |         |
  v    v    v         v
  adguard.  wg.      LAN clients
  DOMAIN    DOMAIN   via VPN
  |
  | DNS upstream (network-internal)
  v
  Unbound (recursive DNS, privacy-first)
  |
  v
  Root DNS Servers
```

### DNS Resolution Chain

```
  LAN/VPN Client --> AdGuard Home (filtering) --> Unbound (recursive) --> Root NS
```

---

## Services

| Service | Description | Access |
|---------|-------------|--------|
| **AdGuard Home** | DNS filtering, ad blocking | `https://adguard.${DOMAIN}` / LAN DNS `:53` |
| **Unbound** | Recursive DNS resolver (AdGuard upstream) | Internal only |
| **wg-easy** | WireGuard VPN + Web UI | `https://wg.${DOMAIN}` / UDP `:51820` |

## Quick Start

```bash
# 1. Ensure base stack is running (Traefik)
cd stacks/base && docker compose up -d

# 2. Copy and edit environment variables
cp .env.example .env
# Edit .env: fill WG_HOST, WG_PASSWORD_HASH, DOMAIN

# 3. Create proxy network (if not exists)
docker network create proxy

# 4. Start network stack
cd stacks/network && docker compose up -d

# 5. First-time AdGuard Home setup
#    Open https://adguard.yourdomain.com
#    Set admin password, set upstream DNS to: unbound:53
```

## Generate wg-easy Password Hash

wg-easy v14+ requires bcrypt password hash:

```bash
docker run -it ghcr.io/wg-easy/wg-easy wgpw YOUR_PASSWORD
# Or: htpasswd -nbBC 12 "" YOUR_PASSWORD | cut -d: -f2
# Paste output into WG_PASSWORD_HASH in .env
```

## AdGuard Home + Unbound Configuration

After initial setup, go to AdGuard Home -> Settings -> DNS Settings:

- **Upstream DNS servers**: `unbound:53`
- **Bootstrap DNS servers**: `1.1.1.1`
- Enable "Parallel requests" for speed

## WireGuard VPN Client Setup

1. Visit `https://wg.${DOMAIN}` and log in to wg-easy
2. Click "New Client" to create a peer
3. Scan QR code or download config file
4. Install WireGuard client on your device and import config

## VPN Clients Using AdGuard DNS

```bash
# Find AdGuard Home container IP
docker inspect adguardhome | grep IPAddress
# Set WG_DEFAULT_DNS=172.20.0.x in .env
```

## Firewall Rules

| Port | Protocol | Service | Required |
|------|----------|---------|----------|
| 53 | TCP+UDP | AdGuard DNS | Yes (LAN DNS) |
| 51820 | UDP | WireGuard VPN | Yes |
| 853 | TCP | DNS-over-TLS | Optional |
| 80 | TCP | Traefik HTTP redirect | Yes |
| 443 | TCP | Traefik HTTPS | Yes |

```bash
# UFW
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw allow 51820/udp
sudo ufw allow 853/tcp

# Security: restrict DNS to LAN/VPN only
sudo ufw allow from 10.8.0.0/24 to any port 53
sudo ufw allow from 192.168.1.0/24 to any port 53
sudo ufw deny 53
```

## Local Development (without Traefik)

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
# AdGuard Home: http://localhost:3000 / http://localhost:8080
# wg-easy:      http://localhost:51821
# Unbound DNS:  localhost:5353
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | - | Base domain |
| `TZ` | No | `Asia/Shanghai` | Timezone |
| `WG_HOST` | Yes | - | Public IP or domain |
| `WG_PASSWORD_HASH` | Yes | - | wg-easy Web UI bcrypt hash |
| `WG_PORT` | No | `51820` | WireGuard listen port |
| `WG_DEFAULT_DNS` | No | (empty) | VPN client default DNS |
| `WG_DEFAULT_ADDRESS` | No | `10.8.0.x` | VPN client IP range |
| `WG_ALLOWED_IPS` | No | `0.0.0.0/0, ::/0` | Allowed IP range |
| `WG_PERSISTENT_KEEPALIVE` | No | `25` | NAT keepalive (seconds) |
| `WG_MTU` | No | `1420` | MTU value |
| `ADGUARD_DNS_PORT` | No | `53` | DNS listen port |
| `ADGUARD_DOT_PORT` | No | `853` | DNS-over-TLS port |
| `ADGUARD_WEB_PORT` | No | `3000` | AdGuard Web UI port |

## FAQ

**Q: AdGuard Home setup changes web UI port from 3000 to 80?**
A: Update `ADGUARD_WEB_PORT=80` in `.env`, restart: `docker compose up -d`

**Q: WireGuard clients cannot access LAN?**
A: Check ip_forward=1, firewall 51820/udp, WG_ALLOWED_IPS includes LAN.

**Q: Unbound slow?**
A: First query 200-500ms (recursive). Cached <5ms. Check UDP/53 outbound.

**Q: Cannot pull ghcr.io in China?**
A: `docker pull ghcr.m.daocloud.io/wg-easy/wg-easy:14`

**Q: Port 53 occupied by systemd-resolved?**
A: Disable stub: `sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf && sudo systemctl restart systemd-resolved`

**Q: How to backup?**
A: `docker run --rm -v adguard-conf:/data -v $(pwd):/backup alpine tar czf /backup/adguard-conf.tar.gz /data`

## CN Mirror Alternatives

| Original Image | CN Mirror |
|----------------|-----------|
| `adguard/adguardhome:v0.107.55` | `registry.cn-hangzhou.aliyuncs.com/adguard/adguardhome:v0.107.55` |
| `mvance/unbound:1.20.0` | `registry.cn-hangzhou.aliyuncs.com/mvance/unbound:1.20.0` |
| `ghcr.io/wg-easy/wg-easy:14` | `ghcr.m.daocloud.io/wg-easy/wg-easy:14` |
