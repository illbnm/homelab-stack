# Robustness Stack — China Network Adaptation

Adapts the homelab for deployment behind the Great Firewall.

## Components
- **Caddy** – reverse proxy with ZeroSSL certificates (works in China)
- **Mirror Registry** – local Docker registry mirror using Alibaba Cloud ACR
- **DNS Proxy** – Alibaba Cloud DDNS for dynamic home IP
- **CN Mirrors** – Alpine/Apk mirrors for faster package downloads

## Deployment
1. Replace `your-aliyun-access-key`, `your-aliyun-secret-key`, and `home.example.com` with your real Alibaba Cloud credentials and domain.
2. Start the stack: `docker compose up -d`
3. Configure all other stacks to use the local mirror registry at `http://localhost:5000`.
