# 🌐 Network Stack (AdGuard Home + WireGuard Easy + Unbound + Cloudflare DDNS)

This stack provides network-wide DNS filtering, recursive DNS resolving, remote WireGuard VPN access, and automatic Cloudflare DDNS updates.

---

## 📦 Services Included

- **AdGuard Home (`v0.107.52`)**: Network-wide ad & tracker blocking DNS server.
- **WireGuard Easy (`v14`)**: Web-managed WireGuard VPN with QR code client generator.
- **Cloudflare DDNS (`v1.14.0`)**: Automatic IPv4/IPv6 dynamic DNS updater.
- **Unbound (`v1.21.1`)**: Local recursive DNS resolver.

---

## ⚙️ Port 53 Systemd-Resolved Resolution

Before launching AdGuard Home, disable systemd-resolved's port 53 stub listener using the utility script:

```bash
# Check port 53 usage
./scripts/fix-dns-port.sh --check

# Apply fix (disables systemd-resolved port 53 binding)
./scripts/fix-dns-port.sh --apply

# Restore original setup if needed
./scripts/fix-dns-port.sh --restore
```

---

## 🚀 Deployment Instructions

```bash
docker compose -f stacks/network/docker-compose.yml up -d
```

---

## 📖 Router & DNS Setup

1. **Router DNS Configuration:** Set your router's primary LAN DNS IP to the host server running AdGuard Home (`192.168.x.x`).
2. **WireGuard VPN Setup:** Access `https://wireguard.${DOMAIN}` or port `51821` to generate client `.conf` files or scan the QR code.
3. **Cloudflare DDNS:** Set `CLOUDFLARE_API_TOKEN` and `DOMAINS` in `.env`.
