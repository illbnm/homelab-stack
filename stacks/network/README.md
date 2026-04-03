# Network Stack

> AdGuard Home + WireGuard Easy + Cloudflare DDNS + Unbound

**Budget:** ~$120 USDT (VPS or NUC + $10/yr domain)

---

## Services

| Service | Image | Ports | Description |
|---------|-------|-------|-------------|
| **Unbound** | `mvance/unbound` | Docker internal | Recursive DNS resolver |
| **AdGuard Home** | `adguard/adguardhome:v0.107.55` | `53/TCP+UDP, 3000/TCP` | DNS filtering + ad-blocking |
| **WireGuard Easy** | `weejewel/wg-easy` | `51820/UDP, 51821/TCP` | VPN with web UI |
| **Cloudflare DDNS** | `hotio/cloudflare-ddns` | — | IPv4 + IPv6 DDNS updater |

---

## DNS Flow

```
Client → AdGuard Home (:53) → Unbound (:53) → Internet (recursive)
```

AdGuard forwards to `172.20.0.1:53` (Unbound container IP). DNSSEC enabled.

---

## Quick Start

### 1. Prerequisites
```bash
docker network create proxy 2>/dev/null || true
```

### 2. Fix Port 53 Conflict (systemd-resolved)
```bash
./scripts/fix-dns-port.sh --check       # diagnose
sudo ./scripts/fix-dns-port.sh --apply   # fix
sudo systemctl restart docker
```

### 3. Configure
```bash
cd stacks/network
cp .env.example .env
# Edit .env: WG_HOST, WG_PASSWORD_HASH, CF_API_*, CF_ZONES
```

### 4. Start
```bash
docker-compose up -d
```

### 5. Set Router DNS
Point your router's DHCP DNS to your server's LAN IP.

---

## AdGuard → Upstream DNS

The `adguard-conf.yaml` is pre-mounted with upstream set to `172.20.0.1:53` (Unbound).

If configuring manually: **Settings → DNS → Upstream DNS**: `172.20.0.1:53`

---

## WireGuard VPN

### Generate Password Hash
```bash
docker run --rm -it ghcr.io/wg-easy/wg-easy wg-easy hash
# Paste output as WG_PASSWORD_HASH in .env
```

### Create Client Config
1. Open `http://<server>:51821`
2. **New Client** → enter name → download `.conf` or scan QR
3. Import into WireGuard app

### Split Tunneling
Full tunnel (default):
```env
WG_ALLOWED_IPS=0.0.0.0/0, ::/0
```

Split tunnel — only route LAN subnet:
```env
WG_ALLOWED_IPS=192.168.1.0/24, ::/0   # .env
AllowedIPs = 192.168.1.0/24, ::/0     # client .conf
```

### Kill Switch (client config)
```
[Interface]
Table = off
PostUp = ip rule add from 192.168.1.x table main
PostDown = ip rule del from 192.168.1.x table main
```

---

## Cloudflare DDNS

**CF_ZONES format:**
```json
[{"zone": "example.com", "records": ["home", "vpn"]}]
```

Updates A (IPv4) and AAAA (IPv6) records every 5 minutes.

| CF_PROXIED | Effect |
|------------|--------|
| `false` | Grey cloud — direct DNS, your server IP is visible |
| `true` | Orange cloud — Cloudflare CDN/proxy (slower) |

---

## Traefik Access

```env
ADGUARD_HOST=adguard.example.com
WG_UI_HOST=wg.example.com
```
Then access via `https://adguard.example.com` and `https://wg.example.com`.

---

## Port Reference

| Port | Protocol | Service |
|------|----------|---------|
| `53` | TCP/UDP | AdGuard Home (DNS) |
| `3000` | TCP | AdGuard Home (Web UI) |
| `51820` | UDP | WireGuard (VPN) |
| `51821` | TCP | WireGuard Easy (Web UI) |

---

## Maintenance

```bash
# Restart
docker-compose restart

# Logs
docker logs -f adguardhome wireguard-easy cloudflare-ddns unbound

# Update
docker-compose pull && docker-compose up -d

# Backup WireGuard keys
tar -czf wireguard-backup.tar.gz wireguard-data/
```

---

## Troubleshooting

**Port 53 in use:**
```bash
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply
sudo systemctl restart docker
```

**WireGuard clients can't connect:**
- Verify `WG_HOST` is your public IP or domain
- Check firewall: `sudo ufw allow 51820/udp`
- Logs: `docker logs wireguard-easy`

**Cloudflare DDNS not updating:**
- Verify `CF_API_KEY` has `Zone.DNS:Edit` permission
- Check `CF_ZONES` JSON syntax
- Logs: `docker logs cloudflare-ddns`
