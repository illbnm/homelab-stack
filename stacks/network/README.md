# Network Stack

Provides core network services for the homelab: DNS filtering, VPN access, and dynamic DNS.

## Services Included

- **AdGuard Home**: DNS filtering and ad blocking.
- **WireGuard Easy**: VPN server with a web-based management UI.
- **Cloudflare DDNS**: Automatically updates Cloudflare DNS records for dynamic IPs.
- **Unbound**: Recursive DNS resolver used as AdGuard Home's upstream.
- **Nginx Proxy Manager**: Alternative reverse proxy manager.

## Prerequisites

Port 53 (UDP/TCP) must be free on the host to run AdGuard Home. Many Linux distributions use `systemd-resolved` which binds to port 53 by default. 

You can use the provided script to free the port:

```bash
# Check if systemd-resolved is blocking port 53
../../scripts/fix-dns-port.sh --check

# Apply fix (disables DNSStubListener)
../../scripts/fix-dns-port.sh --apply

# (Optional) Restore default behavior
../../scripts/fix-dns-port.sh --restore
```

## Setup Instructions

1. Copy the example environment file and configure it:
   ```bash
   cp .env.example .env
   nano .env
   ```

2. Start the stack:
   ```bash
   docker compose up -d
   ```

## Configuration

### AdGuard Home
- **Web UI**: Access via `https://adguard.example.com`
- **Upstream DNS**: In the AdGuard Home UI, go to Settings -> DNS settings. Set the upstream DNS server to `127.0.0.11` (Docker resolver) or directly to `unbound` (the hostname of the unbound container).
- **Filter Lists**: We recommend adding [OISD](https://oisd.nl/) or similar comprehensive blocklists.

### WireGuard Easy
- **Web UI**: Access via `https://wg.example.com`
- **VPN Clients**: You can create new clients and download configs or scan QR codes via the Web UI.
- **Split Tunneling**: To only route local homelab traffic (and DNS) over the VPN, modify `WG_ALLOWED_IPS` in `.env` to include your internal subnets (e.g., `192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12`). Leave `0.0.0.0/0` if you want all traffic to pass through the VPN.
- **DNS**: Ensure `WG_DEFAULT_DNS` in `.env` points to your AdGuard Home's host IP (e.g., `192.168.1.100`). This ensures VPN clients use your local AdGuard Home for ad-blocking and local name resolution.

### Cloudflare DDNS
- Supports IPv4 and IPv6 out-of-the-box.
- Configure `CF_API_TOKEN` and `CF_DOMAINS` in `.env`.
- Ensure your API token has `Zone.DNS` edit permissions.

## CN Mirrors
If you have trouble pulling images from `ghcr.io` or Docker Hub in mainland China, uncomment the alternative image tags in `docker-compose.yml` (e.g., `swr.cn-north-4.myhuaweicloud.com/...`).
