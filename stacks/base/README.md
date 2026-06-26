# Base Stack

This is the foundational stack for the entire HomeLab project. All other services depend on this stack.

## Services Included

- **Traefik (v3.1.6)**: Reverse Proxy and automatic HTTPS certificate generation.
- **Portainer CE (2.21.3)**: Docker container management UI.
- **Watchtower (1.7.1)**: Automatic updates for Docker containers.
- **Socket Proxy (0.2.0)**: Securely isolates the Docker socket, limiting access to only what Traefik needs.

## Setup Instructions

1. Copy the sample environment file:
   ```bash
   cp .env.example .env
   ```
2. Update the `.env` file with your domain, email, and Traefik dashboard basic auth credentials.
3. Start the stack:
   ```bash
   docker network create proxy # if not already created
   docker compose up -d
   ```

## DNS Configuration

To make your services accessible, configure your DNS provider as follows:

1. Create an `A` record for your root domain pointing to your server's IP address.
2. Create a CNAME or Wildcard `A` record (`*.example.com`) pointing to your server's IP to handle all subdomains dynamically.
3. Ensure ports 80 and 443 are port-forwarded from your router to the server if hosting locally.

## Certificate Configuration (Let's Encrypt)

Traefik is pre-configured to handle certificates automatically via Let's Encrypt. 

### HTTP Challenge (Default)
By default, Traefik uses the HTTP-01 challenge. It requires port 80 to be accessible from the internet. No extra configuration is needed beyond setting `ACME_EMAIL` in the `.env` file.

### DNS Challenge (Wildcard Certificates)
If you want wildcard certificates or cannot expose port 80:
1. Open `config/traefik/traefik.yml` and enable the `letsencrypt-dns` section.
2. Provide your DNS provider name.
3. Add the required DNS API credentials as environment variables to the Traefik service in `docker-compose.yml`. For example, for Cloudflare:
   ```yaml
   environment:
     - CF_API_EMAIL=your-email@example.com
     - CF_DNS_API_TOKEN=your-cloudflare-api-token
   ```
4. Change the `certresolver` label on your containers to use `letsencrypt-dns` instead of `letsencrypt`.