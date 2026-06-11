# Base Infrastructure Stack

This directory contains the Docker Compose configuration for the homelab base stack:
- **Traefik** – reverse proxy with automatic Let's Encrypt HTTPS
- **Socket Proxy** – secure Docker socket access for containers
- **Portainer** – container management UI
- **Watchtower** – automatic container updates

## Deployment

1. Edit the Traefik certificate email in `docker-compose.yml` (replace `admin@example.com`).
2. Start the stack:  
   `docker compose up -d`
3. Access Portainer at `https://<your-ip>:9443` (or configure DNS for `portainer.localhost`).
