# Homelab Network Stack

This repository provides a Docker Compose setup for a robust homelab network stack, including DNS filtering (AdGuard Home), VPN access (WireGuard Easy), dynamic DNS (Cloudflare DDNS), and a reverse proxy (Nginx Proxy Manager).

## Services Included

| Service               | Image                                  | Purpose                                     |
|-----------------------|----------------------------------------|---------------------------------------------|
| AdGuard Home          | `adguard/adguardhome:v0.107.52`        | DNS filtering, ad-blocking, local DNS       |
| Unbound               | `mvance/unbound:1.21.1`                | Recursive DNS resolver (upstream for AdGuard Home) |
| WireGuard Easy        | `ghcr.io/wg-easy/wg-easy:14`           | VPN server with web UI for client management |
| Cloudflare DDNS       | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | Dynamic DNS updates for Cloudflare          |
| Nginx Proxy Manager   | `jc21/nginx-proxy-manager:latest`      | Reverse proxy, SSL termination, web UI      |

## Prerequisites

*   **Docker & Docker Compose**: Ensure Docker and Docker Compose are installed on your host machine.
*   **Public IP / Domain**: You need a public IP address or a domain name pointing to your homelab for WireGuard and Nginx Proxy Manager to be accessible from outside your network.
*   **Cloudflare Account**: For Cloudflare DDNS, you need a Cloudflare account with a managed domain.
*   **Port Forwarding**: You will need to configure port forwarding on your router for the following ports to your homelab server's IP address:
    *   `53/UDP`, `53/TCP` (for AdGuard Home, if you want to use it as your router's DNS)
    *   `51820/UDP` (for WireGuard VPN)
    *   `80/TCP`, `443/TCP` (for Nginx Proxy Manager)
    *   `51821/TCP` (for WireGuard Easy Web UI, optional, can be proxied by NPM)
    *   `3000/TCP` (for AdGuard Home Web UI, optional, can be proxied by NPM)
    *   `81/TCP` (for Nginx Proxy Manager Admin UI, optional, can be proxied by NPM)

## Setup Instructions

### 1. Clone the Repository

