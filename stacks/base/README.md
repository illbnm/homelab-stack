

# Base Infrastructure

This directory contains the base infrastructure for our Docker environment.

## Setup Instructions

1. DNS Configuration:
   - Create A records for your domain pointing to your server's IP address
   - Create wildcard or specific subdomain records for:
     - `traefik.${DOMAIN}`
     - `portainer.${DOMAIN}`

2. Create a `.env` file from `.env.example` and update the values:
   ```bash
   cp .env.example .env
   ```

3. Edit the `.env` file to set your domain, email, and other configuration values:
   - Set `DOMAIN` to your domain name
   - Set `ACME_EMAIL` to your email for Let's Encrypt
   - Generate a secure password for Traefik Basic Auth using `htpasswd`:
     ```bash
     htpasswd -nb admin securepassword
     ```
   - Set `TRAEFIK_AUTH` to the output from the above command

4. Create the external Docker network:
   ```bash
   docker network create proxy
   ```

5. Start the services:
   ```bash
   docker-compose up -d
   ```

## Services

- **Traefik**: Reverse proxy and load balancer with automatic HTTPS via Let's Encrypt
- **Portainer**: Docker management UI
- **Watchtower**: Automatic container updates
- **Docker Socket Proxy**: Secure proxy for Docker socket

## Access

- Traefik Dashboard: `https://traefik.${DOMAIN}`
- Portainer: `https://portainer.${DOMAIN}`

## Let's Encrypt Certificates

Traefik will automatically request and renew TLS certificates from Let's Encrypt. Certificates are stored in `/workspace/letsencrypt/acme.json`.

## Configuration

All Traefik configuration is in the `config/traefik` directory.

