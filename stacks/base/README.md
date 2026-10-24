# Base Infrastructure Stack — Traefik + Portainer + Watchtower + Socket Proxy

> **Bounty:** [illbnm/homelab-stack#1](https://github.com/illbnm/homelab-stack/issues/1) — $180 USD

## Overview
Foundational infrastructure providing reverse proxy, automated HTTPS, Docker UI, and safe socket proxying.

## Services
- **Traefik v3.1.6:** Core reverse proxy & TLS termination
- **Docker Socket Proxy 0.2.0:** Hardened Docker daemon access
- **Portainer CE 2.21.3:** Management UI
- **Watchtower 1.7.1:** Automated scheduled container updates

## Setup
```bash
cp .env.example .env
docker compose up -d
```
