# Network Stack

Provides core network services: DNS filtering, recursive DNS, VPN access, and Dynamic DNS.

## Included Services

- **AdGuard Home**: DNS sinkhole to block ads and trackers.
- **Unbound**: Recursive DNS resolver (upstream for AdGuard) to improve privacy.
- **WireGuard Easy**: VPN server + Web UI.
- **Cloudflare DDNS**: Automatically updates your Cloudflare DNS records with your home IP.
- **Nginx Proxy Manager**: Optional reverse proxy alternative to Traefik.

## System Configuration (Fixing Port 53)

AdGuard Home needs to bind to port 53 to serve DNS requests. By default, many Linux distributions run `systemd-resolved` which already occupies port 53.

Use the provided script to safely free port 53:

```bash
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply
```

If you ever need to revert it:
```bash
sudo ./scripts/fix-dns-port.sh --restore
```

## Setup & Configuration

1. Copy `.env.example` to `.env` and fill in the required variables (like Wireguard Host, Password hash, Cloudflare tokens).
2. Start the stack: `docker compose up -d`
3. Access AdGuard Home via Traefik (`adguard.local.lan` or port 3000 initially).

### AdGuard Upstream Config (Unbound)

Once AdGuard is running, go to **Settings > DNS settings** and set your **Upstream DNS servers** to:

```text
127.0.0.1:5335
# Or if using docker networking hostname:
172.x.x.x (unbound container IP)
```
*(If unbound is on the same host network, `127.0.0.1:5335` works if configured, otherwise use the proxy network IP or `unbound` hostname).* 

### WireGuard & Split Tunneling

The default `.env.example` restricts WireGuard clients to internal networks only via:
`WG_ALLOWED_IPS=192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12`

If you want your VPN clients to route *all* traffic through your home network (full tunnel), change this to:
`WG_ALLOWED_IPS=0.0.0.0/0, ::/0`

Clients will use AdGuard Home for DNS, providing them with ad-blocking even when roaming on mobile networks!
