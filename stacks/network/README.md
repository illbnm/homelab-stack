# 🌐 Network Stack

> Complete network infrastructure with DNS filtering, VPN, and dynamic DNS.

## 🎯 Bounty: [#4](../../issues/4) - $120 USDT

## 📋 Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **AdGuard Home** | `adguard/adguardhome:v0.107.52` | 53/TCP,53/UDP,3000 | DNS filtering + ad blocking |
| **Unbound** | `mvance/unbound:1.21.1` | 54/TCP,54/UDP | Recursive DNS resolver |
| **WireGuard Easy** | `ghcr.io/wg-easy/wg-easy:14` | 51820/UDP,51821/TCP | VPN server with Web UI |
| **Cloudflare DDNS** | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | - | Dynamic DNS updater |

## 🚀 Quick Start

```bash
# 1. Copy environment example
cp .env.example .env

# 2. Edit environment variables (especially Cloudflare API token)
nano .env

# 3. Start the stack
cd /home/zhaog/.openclaw/workspace/data/bounty-projects/homelab-stack
docker compose -f stacks/network/docker-compose.yml up -d

# 4. Check status
docker compose -f stacks/network/docker-compose.yml ps
```

## ⚙️ Configuration

### Environment Variables

```bash
# Domain
DOMAIN=example.com

# Timezone
TZ=Asia/Shanghai

# WireGuard
WIREGUARD_PASSWORD=your-secure-password

# Cloudflare DDNS
CLOUDFLARE_API_TOKEN=your-api-token
CLOUDFLARE_DOMAINS=example.com,www.example.com
```

### Access URLs

After deployment:

- **AdGuard Home Dashboard**: `https://adguard.${DOMAIN}`
- **WireGuard Web UI**: `https://vpn.${DOMAIN}`

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| AdGuard Home | admin | (set on first login) |
| WireGuard | - | `${WIREGUARD_PASSWORD}` |

## 📝 Service Details

### AdGuard Home

**Features:**
- DNS-based ad blocking
- Parental controls
- Safe browsing protection
- Query logs and statistics

**Configuration:**
- Web UI: Port 3000 (proxied via Traefik)
- DNS: Port 53 (TCP/UDP)
- Upstream: Points to Unbound (port 54)

**Recommended Filters:**
- AdGuard DNS filter
- OISD Big
- Spam404
- Malware Domain List

### Unbound

**Purpose:** Local recursive DNS resolver for privacy

**Configuration:**
- Listens on port 54 (to avoid conflict with AdGuard)
- Validates DNSSEC
- Caches responses for performance

**AdGuard Upstream Configuration:**
```
In AdGuard Home Settings → DNS Settings:
Upstream DNS server: 127.0.0.1:54
```

### WireGuard Easy

**Features:**
- Web-based management UI
- QR code generation for mobile clients
- Client configuration download
- Real-time traffic statistics

**Client Configuration:**
- DNS: Points to AdGuard Home (10.8.0.1)
- Split tunneling supported
- Default allowed IPs: 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12

**Mobile Setup:**
1. Access Web UI at `https://vpn.${DOMAIN}`
2. Create new client
3. Scan QR code with WireGuard app
4. Connect and verify DNS goes through AdGuard

### Cloudflare DDNS

**Purpose:** Keep DNS records updated with your dynamic IP

**Setup:**
1. Generate Cloudflare API token (limited scope: `Zone:DNS:Edit`)
2. Set `CLOUDFLARE_DOMAINS` to your domains
3. Enable IPv4 and IPv6 support

**API Token Permissions:**
```
Zone Resources:
  - Zone: DNS: Edit
  
Account Resources:
  - None (not needed)
```

## 🔧 Special Scripts

### Fix DNS Port Conflict

Create `scripts/fix-dns-port.sh`:

```bash
#!/bin/bash
# Fix systemd-resolved 53 port conflict

case "$1" in
    --check)
        echo "Checking systemd-resolved status..."
        systemctl status systemd-resolved
        ss -tulnp | grep :53
        ;;
    --apply)
        echo "Disabling systemd-resolved DNS stub listener..."
        cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=127.0.0.1#54
DNSStubListener=no
EOF
        systemctl restart systemd-resolved
        echo "Done! Restart AdGuard Home if needed."
        ;;
    --restore)
        echo "Restoring systemd-resolved..."
        sed -i 's/DNSStubListener=no/DNSStubListener=yes/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
        echo "Restored!"
        ;;
    *)
        echo "Usage: $0 {--check|--apply|--restore}"
        exit 1
        ;;
esac
```

Make it executable:
```bash
chmod +x scripts/fix-dns-port.sh
```

## ✅ Verification Checklist

- [ ] AdGuard Home accessible at `https://adguard.${DOMAIN}`
- [ ] AdGuard can resolve DNS queries
- [ ] Ad blocking functional (test with adblock-tester.com)
- [ ] Unbound running and responding on port 54
- [ ] WireGuard Web UI accessible
- [ ] WireGuard client can connect
- [ ] VPN traffic routes through AdGuard DNS
- [ ] Cloudflare DDNS updating correctly
- [ ] `fix-dns-port.sh` handles systemd-resolved conflict
- [ ] All services have valid HTTPS certificates

## 🐛 Troubleshooting

### Port 53 Already in Use

```bash
# Check what's using port 53
sudo ss -tulnp | grep :53

# If systemd-resolved, run fix script
./scripts/fix-dns-port.sh --apply
```

### WireGuard Connection Fails

```bash
# Check firewall rules
sudo ufw allow 51820/udp

# Verify NAT/masquerading
sudo iptables -t nat -L POSTROUTING
```

### DDNS Not Updating

```bash
# Check logs
docker logs cloudflare-ddns

# Verify API token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
```

### DNS Resolution Slow

```bash
# Check Unbound is caching
docker exec unbound ubctl stats

# Test DNS speed
dig @127.0.0.1 -p 54 example.com
```

## 📚 Related Stacks

- [Base](../base/) - Traefik reverse proxy (required)
- [Monitoring](../monitoring/) - Track DNS/VPN performance
- [Dashboard](../dashboard/) - Portainer for container management

## 🌾 Router Configuration

For best results, configure your router:

1. **DNS Settings:**
   - Primary DNS: `192.168.1.x` (AdGuard Home host IP)
   - Secondary DNS: `1.1.1.1` (backup)

2. **Port Forwarding:**
   - `51820/UDP` → WireGuard host (for remote VPN access)

3. **DHCP Options:**
   - Option 6 (DNS): Point to AdGuard Home

---

*Bounty: $120 USDT | Status: In Progress*
