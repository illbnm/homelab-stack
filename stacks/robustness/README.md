# Robustness Stack

Network resilience for China/mainland users and general homelab infrastructure
robustness. This stack is **optional** but strongly recommended for any
production homelab — especially if you're running services exposed to the
internet.

## What's Included

| Service | Version | Purpose |
|---------|---------|---------|
| Cloudflare DDNS | hotio/cloudflare-ddns:1.9.0 | Auto-update DNS A record when public IP changes |
| Dnsmasq | andreysmg/dnsmasq:1.0.1 | Local DNS resolver with ad-blocking |
| Network Test Runner | alpine:3.20 | Scheduled connectivity checks (every hour) |

## Architecture

```
Internet
  │
  │  Dynamic public IP changes detected
  ▼
Cloudflare DDNS → Updates CF_DOMAIN A record → Points back to your router
  │
  │  LAN DNS query (e.g. laptop.dlan)
  ▼
Dnsmasq (10.8.0.1:53)
  │
  ├──► CN mode: forwards to 223.6.6.6 / 119.29.29.29 (Alibaba/Tencent DNS)
  │
  └──► INTL mode: forwards to 1.1.1.1 / 8.8.8.8 (Cloudflare/Google DNS)
        │
        └──► Ad domains → 0.0.0.0 (blocked)

Network Test Runner → Checks connectivity to CN/INTL endpoints every hour
```

## Quick Start

```bash
cd stacks/robustness

# 1. Copy environment file and fill in values
cp .env.example .env
$EDITOR .env   # fill in CF_API_KEY, CF_ZONE_ID, CF_DOMAIN, REGION

# 2. Ensure the proxy network exists
docker network create proxy 2>/dev/null || true

# 3. Start the stack
docker compose up -d

# 4. Verify services are running
docker compose ps
docker compose logs --tail=20
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ | — | Base domain, e.g. `home.example.com` |
| `TZ` | ✅ | `Asia/Shanghai` | Container timezone |
| `REGION` | ✅ | `CN` | `CN` = China-optimized DNS; `INTL` = global |
| `CF_API_KEY` | ✅ | — | Cloudflare Global API Key |
| `CF_ZONE_ID` | ✅ | — | Cloudflare Zone ID |
| `CF_DOMAIN` | ✅ | — | Domain to keep updated (e.g. `home.example.com`) |

### Getting Cloudflare Credentials

1. **Zone ID**: Cloudflare Dashboard → Your domain → Overview → scroll to API Zone ID
2. **API Key**: Cloudflare Dashboard → Profile → API Tokens → Global API Key
   - Or create a scoped token with "Edit zone DNS" permission for the specific zone

## DNS Setup

### Setting Dnsmasq as Your LAN DNS

1. After starting, Dnsmasq listens on `10.8.0.1:53`
2. Set this IP as your router's DHCP DNS server, or set it manually on devices
3. For devices that can't use custom DNS (smart TVs, consoles), set the DNS
   in your router's LAN DHCP settings

### Router DNS Override (Example)

```
Router admin panel → LAN Settings → DHCP Server → DNS Server → 10.8.0.1
```

### Test Dnsmasq is Working

```bash
# From any machine on the LAN
nslookup google.com 10.8.0.1
# Should return Google's IP (not blocked)

nslookup doubleclick.net 10.8.0.1
# Should return 0.0.0.0 (blocked)
```

## NAT Loopback / Hairpin NAT

**Required if you want to access your own domain from inside your LAN.**

NAT loopback (also called hairpin NAT) lets devices on your LAN reach your
public domain by going through your router's public IP, which then forwards
back in. This is important for testing your setup from inside the network.

### How to Enable

This depends on your router's firmware. Here are common scenarios:

#### OpenWrt / LEDE

```bash
# SSH into router
ssh root@192.168.1.1

# Add to /etc/config/firewall (in the lan zone config):
option masq '1'
option masq_source '!192.168.1.0/24'
option masq_dest '!192.168.1.0/24'

# Or use LuCI:
# Network > Firewall > LAN zone > Edit > "Masquerading" ✓ enabled
# Advanced Settings > "Unrestricted" (optional)
```

#### pfSense / OPNsense

```bash
# pfSense: Firewall > NAT > Outbound
# Set Outbound NAT Mode to "Hybrid" or "Automatic"
# Ensure a rule exists for LAN net → WAN with translation
```

#### Generic Consumer Router

Most consumer routers don't support NAT loopback (hairpin NAT). Options:

1. **Use the LAN IP directly** for internal access (e.g. `http://192.168.1.100`)
2. **Add a local hosts entry** on each device:
   ```
   # /etc/hosts (Linux/macOS) or C:\Windows\System32\drivers\etc\hosts
   192.168.1.100  home.yourdomain.com
   ```
3. **Consider flashing OpenWrt** if your router supports it
4. **Use a Pi-hole** as DNS and configure it to split DNS:
   - Return LAN IPs for local domains
   - Return public IPs (via upstream) for everything else

## Network Test Script

The `network-test` container runs `scripts/network-test.sh` every hour.
Logs are stored in the `network-test-logs` Docker volume.

### View Recent Logs

```bash
docker exec network-test cat /var/log/network-test/connectivity.log | tail -50
```

### Manual Run

```bash
docker exec network-test bash /scripts/network-test.sh
```

## Troubleshooting

### Cloudflare DDNS not updating

```bash
# Check logs
docker compose logs cloudflare-ddns

# Common issues:
# - CF_API_KEY is Global API Key, NOT a scoped Zone Token
# - CF_ZONE_ID is the Zone ID, not the Account ID
# - CF_DOMAIN must match the exact DNS record name
```

### Dnsmasq not responding

```bash
# Check logs
docker compose logs dnsmasq

# Verify the port is bound correctly
docker exec dnsmasq netstat -tlnp | grep :53

# Test resolution from inside container
docker exec dnsmasq nslookup google.com
```

### Network test showing failures

The test checks reachability to:
- CN targets: Baidu (www.baidu.com), Alibaba (www.alibaba.com), Tencent (www.qq.com)
- INTL targets: Google (www.google.com), Cloudflare (www.cloudflare.com), GitHub (www.github.com)

If CN targets fail from INTL mode (or vice versa), this is expected if those
services are blocked in your region. Check the `REGION` setting.
