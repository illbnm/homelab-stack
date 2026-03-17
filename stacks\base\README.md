# 🏗️ Base Infrastructure Stack

> Traefik v3 · Portainer CE · Watchtower · Docker Socket Proxy

This is the **foundation layer** of HomeLab Stack. Every other stack depends on the shared `proxy` network and the reverse proxy provided here. Deploy this stack first.

---

## 📦 Services

| Container | Image | Purpose |
|-----------|-------|---------|
| `traefik` | `traefik:v3.1.6` | Reverse proxy + automatic HTTPS (Let's Encrypt) |
| `portainer` | `portainer/portainer-ce:2.21.3` | Docker management web UI |
| `watchtower` | `containrrr/watchtower:1.7.1` | Automatic container updates |
| `socket-proxy` | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker socket isolation |

---

## 🚀 Quick Start

### 1. Create the shared proxy network

This only needs to be done **once** per Docker host:

