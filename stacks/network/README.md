# Network Stack

DNS, ad-blocking, and time synchronization services for the homelab.

## Services

| Service | Image | Ports | Purpose |
|---------|-------|-------|---------|
| Pi-hole | `pihole/pihole:5.26` | 53, 80 | DNS sinkhole with ad-blocking |
| Unbound | `mvance/unbound:1.20.0` | 5335 | Recursive DNS resolver |
| NTP | `cturra/ntp:latest` | 123/udp | Network time protocol |

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
nano .env

# 2. Start services
docker compose up -d

# 3. Access Pi-hole admin
# https://pihole.yourdomain.com/admin
```

## Architecture

```
                    ┌──────────────────┐
                    │    Clients       │
                    └────────┬─────────┘
                             │ DNS queries
                             ▼
                    ┌──────────────────┐
                    │    Pi-hole       │
                    │  (port 53)       │
                    │  - Ad blocking   │
                    │  - Local DNS     │
                    └────────┬─────────┘
                             │ Upstream DNS
                             ▼
                    ┌──────────────────┐
                    │    Unbound       │
                    │  (port 5335)     │
                    │  - Recursive     │
                    │  - DNSSEC        │
                    └──────────────────┘
```

## Configuration

### Pi-hole

#### Admin Access

- URL: `https://pihole.${DOMAIN}/admin`
- Password: Set via `PIHOLE_PASSWORD`

#### Local DNS Records

Edit `config/pihole/01-local.conf` to add custom DNS records:

```conf
# Static records
address=/myservice.home.arpa/192.168.1.100

# Wildcard (all *.domain.local)
address=/domain.local/192.168.1.10
```

#### Whitelist/Blacklist

```bash
# Whitelist a domain
docker exec pihole pihole -w example.com

# Blacklist a domain
docker exec pihole pihole -b ads.example.com

# Reload lists
docker exec pihole pihole -g
```

### Unbound

#### DNS over HTTPS (DoH)

To enable DoH upstream, create `config/unbound/conf.d/doh.conf`:

```conf
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 8.8.8.8@853#dns.google
```

#### Custom DNS Records

For local DNS resolution without Pi-hole:

```conf
# config/unbound/conf.d/local.conf
local-zone: "home.arpa." static
local-data: "router.home.arpa. IN A 192.168.1.1"
local-data: "nas.home.arpa. IN A 192.168.1.2"
```

### NTP

#### Configure NTP Servers

```bash
# Set custom NTP servers
export NTP_SERVERS=time.cloudflare.com,time.google.com

# Check status
docker exec ntp chronyc sources
docker exec ntp chronyc tracking
```

## DNS Resolution Flow

1. **Client** sends DNS query to Pi-hole (port 53)
2. **Pi-hole** checks:
   - Local DNS records → Return immediately
   - Blocked domains → Return 0.0.0.0
   - Otherwise → Forward to Unbound
3. **Unbound** performs recursive resolution with DNSSEC validation
4. Response cached and returned to client

## Health Checks

```bash
# Test DNS resolution
dig @192.168.1.10 google.com

# Test Pi-hole
docker exec pihole pihole status

# Test Unbound
docker exec unbound unbound-control status

# Test NTP
docker exec ntp chronyc tracking
```

## Integration with Other Stacks

### Configure Services to Use Pi-hole

```yaml
services:
  myapp:
    dns: 192.168.1.10  # Pi-hole IP
    # or use Docker network DNS
```

### Router Configuration

Set Pi-hole as the DNS server for your network:

```bash
# On router DHCP settings
DNS Server 1: 192.168.1.10
DNS Server 2: (leave empty or use secondary)
```

## Monitoring

### DNS Query Stats

```bash
# Pi-hole stats
docker exec pihole pihole -c

# Or via API
curl -s "http://pihole:80/admin/api.php?summaryRaw" | jq
```

### Top Queries

```bash
# Top permitted domains
docker exec pihole pihole -t -p

# Top blocked domains
docker exec pihole pihole -t -b
```

## Troubleshooting

### DNS Not Resolving

```bash
# Check Pi-hole status
docker logs pihole

# Check Unbound status
docker logs unbound

# Test direct query
dig @127.0.0.1 -p 5335 google.com
```

### Ad Blocking Not Working

```bash
# Update blocklists
docker exec pihole pihole -g

# Check gravity database
docker exec pihole sqlite3 /etc/pihole/gravity.db "SELECT COUNT(*) FROM gravity;"
```

### Time Sync Issues

```bash
# Check NTP status
docker exec ntp chronyc tracking

# Force sync
docker exec ntp chronyc makestep
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Pi-hole | 128 MB | 256 MB |
| Unbound | 64 MB | 128 MB |
| NTP | 16 MB | 32 MB |
| **Total** | **208 MB** | **416 MB** |

## Security Considerations

1. **DNSSEC**: Enabled by default on Unbound
2. **QNAME Minimization**: Prevents data leakage
3. **Rate Limiting**: Prevents DNS amplification attacks
4. **Access Control**: Only local networks allowed
5. **Web UI**: Protected by Traefik + password

## License

MIT
