# Network Stack — AdGuard Home + WireGuard Easy + Cloudflare DDNS + Unbound

## Resolving `systemd-resolved` Port 53 Conflict

```bash
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply
```

## Router DNS & Split-Tunneling Setup

1. Point router DHCP Primary DNS to your HomeLab host IP (`53/UDP`).
2. Configure AdGuard Home upstream DNS to `172.29.0.53:53` (`unbound` local recursive DNSSEC resolver).
3. For WireGuard split tunneling, set `WG_ALLOWED_IPS=10.8.0.0/24,192.168.1.0/24`; for full-tunnel mode, set `WG_ALLOWED_IPS=0.0.0.0/0,::/0`.
