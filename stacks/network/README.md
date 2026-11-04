# Network Stack

High-performance homelab networking infrastructure covering network-wide ad blocking, privacy-preserving recursive DNS resolution, WireGuard VPN remote access, and automated Cloudflare Dynamic DNS.

## Services Included

| Service | Version | Web Port / Domain | Protocol Ports | Purpose |
|---|---|---|---|---|
| **AdGuard Home** | `v0.107.52` | `https://adguard.${DOMAIN}` | 53 (TCP/UDP), 3000 | Ad blocking, DNS sinkhole, family filter |
| **Unbound** | `1.21.1` | Internal | 5335 (TCP/UDP) | Local validating recursive DNS resolver |
| **WireGuard Easy** | `14` | `https://vpn.${DOMAIN}` | 51820 (UDP) | Fast VPN tunnel with web-based QR codes |
| **Cloudflare DDNS** | `1.14.0` | Background | N/A | Syncs WAN IP with Cloudflare DNS records |

## Port 53 Conflict Resolution

Linux hosts with `systemd-resolved` bind port 53 by default. Run the included script:

```bash
# 1. Check port 53 status
bash scripts/fix-dns-port.sh --check

# 2. Automatically apply stub release and symlink
sudo bash scripts/fix-dns-port.sh --apply

# 3. To restore anytime
sudo bash scripts/fix-dns-port.sh --restore
```

## Router DNS Configuration

To protect all devices in your home network automatically:
1. Navigate to your home router administration page (e.g. `192.168.1.1`).
2. Go to **DHCP / LAN Settings**.
3. Set **Primary DNS Server** to your server's local LAN IP (e.g., `192.168.1.100`).
4. Save and reboot your router.

## Quick Start

```bash
# Deploy stack
docker compose -f stacks/network/docker-compose.yml up -d
```
