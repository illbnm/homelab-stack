# 🏗️ Base Infrastructure Stack (Traefik + Portainer + Watchtower + Socket Proxy)

This stack provides the core reverse proxy, TLS termination, container management UI, and automated container updates for the Homelab ecosystem.

---

## 📦 Services Included

- **Traefik (`v3.1.6`)**: High-performance reverse proxy and Let's Encrypt TLS manager (`traefik.${DOMAIN}`).
- **Portainer CE (`2.21.3`)**: Docker GUI management platform (`portainer.${DOMAIN}`).
- **Watchtower (`1.7.1`)**: Automated container update daemon (runs daily at 3:00 AM).
- **Docker Socket Proxy (`0.2.0`)**: Secure read-only Docker socket proxy.

---

## 🌐 External Network Creation

Create the external `proxy` network before launching any stack:

```bash
docker network create proxy
```

---

## 🚀 Launch Instructions

```bash
# Set up acme.json permissions
touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# Launch base stack
docker compose -f stacks/base/docker-compose.yml up -d
```