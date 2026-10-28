# 🌐 Network Stack (AdGuard Home, WireGuard Easy, Cloudflare DDNS, Unbound)

> Private DNS privacy, recursive resolution, wireguard tunnel, and dual-stack dynamic DNS.

## 📦 Services

| Service | Image | External Port | Description |
|---|---|---|---|
| **AdGuard Home** | `adguard/adguardhome:v0.107.52` | 53/UDP, 53/TCP | DNS ad-blocking & filtering |
| **Unbound** | `mvance/unbound:1.21.1` | Internal (53) | Recursive privacy DNS resolver |
| **WireGuard Easy** | `ghcr.io/wg-easy/wg-easy:14` | 51820/UDP | Fast VPN server with Web UI |
| **Cloudflare DDNS** | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | Host Network | Dual-stack IPv4/IPv6 auto DDNS |

## 🛠️ Port 53 Host Binding Fix
Run `./scripts/fix-dns-port.sh --apply` to release systemd-resolved port 53.
