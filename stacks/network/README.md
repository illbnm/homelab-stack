# 🌐 Network Stack

> DNS filtering, ad-blocking, and reverse proxy management.

**Services:** AdGuard Home · Nginx Proxy Manager  

---

## 🏗️ Architecture

```
Internet
    │
    ├──► Port 53 (DNS) ──► AdGuard Home ──► Upstream DNS (e.g. Cloudflare 1.1.1.1)
    │                           │
    │                           ├──► Block ads + trackers
    │                           └──► Local DNS records (local.domain → 192.168.x.x)
    │
    └──► Port 8181 ──► Nginx Proxy Manager ──► Alternative proxy management UI
                            (manages reverse proxy configs without YAML)
```

**AdGuard Home** is a DNS-level ad-blocker and DHCP server replacement. Configure your router to use the homelab IP as the DNS server, and all devices on your network get ad-blocking automatically.

**Nginx Proxy Manager** provides a web UI for managing reverse proxy hosts, SSL certificates, and access control — useful as a supplement to or alternative for Traefik.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Base infrastructure must be running first
docker network create proxy 2>/dev/null || true

# IMPORTANT: Ports 53 (TCP+UDP), 8181 must be available on the host
# Stop any existing DNS services first:
sudo systemctl stop systemd-resolved  # on systemd systems
sudo systemctl disable systemd-resolved
```

### 2. Configure environment

```bash
cd stacks/network
cp .env.example .env
nano .env
```

Required `.env` variables:

```env
DOMAIN=yourdomain.com
TZ=Asia/Shanghai
```

### 3. Configure AdGuard Home as your network DNS

**Option A — Router DHCP settings:**
1. Log into your router
2. Find DNS settings (usually under LAN or DHCP)
3. Set Primary DNS = `<homelab-server-ip>`
4. Save and restart router DHCP

**Option B — Manual per-device:**
Set DNS to `<homelab-server-ip>` on each device.

**Option C — systemd-resolved override (advanced):**

```bash
# On the homelab server itself
sudo mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/adguard.conf << 'EOF'
[Resolve]
DNS=127.0.0.1
DNSStubListener=no
EOF
sudo systemctl restart systemd-resolved
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Initial setup

#### AdGuard Home — first-run wizard

1. Visit `https://dns.${DOMAIN}` (or `http://<server-ip>:3000` on first run)
2. Follow the setup wizard:
   - Admin web interface port: `3000`
   - DNS port: `53` (both TCP and UDP)
   - Upstream DNS servers: `https://dns.cloudflare.com/dns-query` + `https://dns.google/dns-query`
3. Create admin account

#### Nginx Proxy Manager — default credentials

1. Visit `https://npm.${DOMAIN}:8181` (port 8181, not 80/443)
2. Default: `admin@example.com` / `changeme`
3. Change password immediately

---

## 🌐 Service URLs (after DNS + Traefik)

| Service | URL | Notes |
|---------|-----|-------|
| AdGuard Home | `https://dns.${DOMAIN}` | Web UI (also port `3000` directly) |
| Nginx Proxy Manager | `https://npm.${DOMAIN}:8181` | Port 8181, not 80/443 |

**Direct access (no Traefik):**
- AdGuard Home: `http://<server-ip>:3000`
- NPM: `http://<server-ip>:8181`

---

## 🔧 AdGuard Home — Key Features

### Add custom DNS rewrite (local domain resolution)

1. `https://dns.${DOMAIN}` → Filters → DNS settings
2. Scroll to "Custom DNS rules"
3. Add: `192.168.1.100 homelab.local` (or use DNS rewrites section)

### Enable ad-blocking blocklists

1. Filters → DNS blocklists
2. Add these popular blocklists:
   - `https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt`
   - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
   - `https://mirror. содействие.pw/StevenBlack/hosts/conjunction_to StevenBlackhosts
   - EasyList, EasyPrivacy (from AdGuard filters)
3. Save and update filters

### Use DNS-over-HTTPS (DoH) client-side

Tell browsers to use AdGuard as DoH:
- AdGuard Home exposes DoH at: `https://dns.${DOMAIN}/dns-query`
- Configure in browser: Firefox → Settings → Privacy → DNS-over-HTTPS → Custom → `https://dns.${DOMAIN}/dns-query`

### DHCP (optional — replaces router DHCP)

AdGuard Home can act as a DHCP server:
1. Settings → DHCP
2. Enable DHCP server
3. Set IP range (e.g. `192.168.1.100` - `192.168.1.250`)
4. Set gateway (your router IP)
5. **Warning:** Disable DHCP on your router first!

---

## 🔧 Nginx Proxy Manager — Key Features

NPM provides a web UI for managing reverse proxy hosts. It's useful for quickly adding new services without editing YAML files.

### Add a proxy host (e.g. for a service without Traefik labels)

1. Open NPM → **Proxy Hosts** → Add Proxy Host
2. Domain names: `myapp.${DOMAIN}`
3. Scheme: `http`
4. Forward hostname/IP: `container-name` or `192.168.x.x`
5. Forward port: `8080`
6. Enable: SSL → Request New SSL Certificate
7. Save

### SSL Certificate Management

NPM auto-requests Let's Encrypt certificates via HTTP-01 challenge. For DNS-01 challenge (for wildcard certs), configure a DNS provider in SSL → Let's Encrypt.

---

## 📁 File Structure

```
stacks/network/
├── docker-compose.yml
├── .env
└── data/
    ├── adguard/
    └── npm/
        ├── data/
        └── letsencrypt/

Docker volumes:
  adguard-work    → /opt/adguardhome/work
  adguard-conf    → /opt/adguardhome/conf
  npm-data        → /data
  npm-letsencrypt → /etc/letsencrypt
```

---

## 🐛 Troubleshooting

### AdGuard Home not intercepting DNS queries

1. Check firewall: UDP port 53 must be open on the host
   ```bash
   sudo ss -ulnp | grep :53
   ```
2. Check if another service is using port 53:
   ```bash
   sudo lsof -i :53
   ```
3. Verify DNS settings on a client device:
   ```bash
   nslookup google.com <homelab-server-ip>
   ```

### AdGuard Home web UI not loading

```bash
# Check logs
docker compose logs adguardhome

# Check if port 3000 is available
sudo ss -tlnp | grep 3000
```

### Nginx Proxy Manager 502 Bad Gateway

1. Check the upstream service is running
2. Verify hostname/IP and port in the proxy host settings
3. Check NPM logs:
   ```bash
   docker compose logs npm
   ```

### SSL certificate not renewing

1. Verify port 80 is open (needed for HTTP-01 challenge)
2. Check NPM → SSL Certificates → check the cert status
3. Try re-issuing: Actions → Delete → Re-request

---

## 🔄 Update services

```bash
cd stacks/network
docker compose pull
docker compose up -d
```

---

## 🗑️ Tear down

```bash
cd stacks/network
docker compose down        # keeps volumes
docker compose down -v    # removes volumes
```

---

## 📋 Acceptance Criteria

- [x] AdGuard Home runs and serves DNS on port 53
- [x] AdGuard Home web UI accessible via Traefik
- [x] Nginx Proxy Manager accessible on port 8181
- [x] Both services have health checks
- [x] Image tags are pinned versions
- [x] README documents setup, DNS configuration, and NPM usage
