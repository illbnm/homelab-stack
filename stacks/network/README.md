# Enterprise Network Stack

A complete, production-ready network solution featuring DNS filtering, recursive DNS, VPN, reverse proxy, and comprehensive monitoring for homelabs and small businesses.

## Features

### 🔒 Multi-Layer DNS Security
- **AdGuard Home**: DNS filtering, ad blocking, parental controls
- **Unbound**: Recursive DNS resolver with DNSSEC validation
- **DNS-over-TLS/HTTPS/QUIC**: Encrypted DNS protocols

### 🌐 Secure Networking
- **WireGuard VPN**: Modern, high-performance VPN with automatic client management
- **Traefik Reverse Proxy**: Automatic HTTPS with Let's Encrypt
- **Network Isolation**: Dedicated Docker network with controlled access

### 📊 Comprehensive Monitoring
- **Netdata**: Real-time performance monitoring and alerting
- **SmokePing**: Network latency and packet loss monitoring
- **Node Exporter**: Hardware and system metrics for Prometheus

### ⚡ Production Ready
- Health checks and automatic restarts
- Resource limits and optimization
- Automated certificate management
- Backup and recovery procedures

## Quick Start

### Prerequisites
- Docker and Docker Compose
- 2GB RAM minimum, 4GB recommended
- Public IP or domain for SSL certificates (optional)

### Installation

1. **Clone or copy the network stack**
   ```bash
   git clone <repository-url>
   cd network-stack
   ```

2. **Configure environment variables**
   ```bash
   cp .env.network.example .env.network
   # Edit .env.network with your settings
   ```

3. **Run the setup script**
   ```bash
   chmod +x scripts/setup-network.sh
   ./scripts/setup-network.sh
   ```

4. **Verify the installation**
   ```bash
   ./scripts/validate-network.sh
   ```

## Service Details

### AdGuard Home
- **Purpose**: DNS filtering, ad blocking, parental controls
- **Web UI**: http://<server-ip>:3000
- **DNS Port**: 53 (TCP/UDP)
- **Encrypted DNS**: TLS (853), HTTPS (443), QUIC (784)
- **Configuration**: `config/adguard/`

### Unbound
- **Purpose**: Recursive DNS resolver with DNSSEC
- **Port**: 53 (TCP/UDP)
- **Features**: Caching, prefetching, privacy enhancements
- **Configuration**: `config/unbound/unbound.conf`

### WireGuard VPN
- **Purpose**: Secure remote access and site-to-site VPN
- **Port**: 51820/UDP
- **Client Management**: Automatic config generation
- **Configuration**: `data/wireguard/config/`

### Traefik
- **Purpose**: Reverse proxy with automatic HTTPS
- **Dashboard**: http://<server-ip>:8080
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Features**: Let's Encrypt integration, middleware support
- **Configuration**: `config/traefik/`

### Monitoring Services
- **Netdata**: http://<server-ip>:19999
- **SmokePing**: http://<server-ip>:8081
- **Node Exporter**: http://<server-ip>:9100/metrics

## Configuration

### Environment Variables
Key variables in `.env.network`:

| Variable | Description | Default |
|----------|-------------|---------|
| `WIREGUARD_SERVER_URL` | VPN server public URL/IP | `auto` |
| `WIREGUARD_PEERS` | Number of client configs to generate | `10` |
| `TRAEFIK_ACME_EMAIL` | Email for Let's Encrypt | `admin@example.com` |
| `PRIMARY_DNS_SERVER` | Primary DNS server IP | `172.21.0.10` |
| `UPSTREAM_DNS_SERVERS` | External DNS servers | `1.1.1.1,8.8.8.8` |

### Security Configuration
1. **Change default passwords** in `.env.network`
2. **Set up proper firewall rules**
3. **Configure Let's Encrypt email** for SSL certificates
4. **Restrict access** to management interfaces
5. **Use strong WireGuard keys**

### Performance Tuning
Adjust based on your hardware:

```bash
# CPU limits
ADGUARD_CPU_LIMIT=1.0
UNBOUND_CPU_LIMIT=0.5
WIREGUARD_CPU_LIMIT=0.3

# Memory limits
ADGUARD_MEMORY_LIMIT=512M
UNBOUND_MEMORY_LIMIT=256M
TRAEFIK_MEMORY_LIMIT=256M

# DNS cache
DNS_CACHE_SIZE=256M
```

## Usage Examples

### DNS Configuration
1. Set your router or devices to use the stack as DNS server:
   ```
   Primary DNS: <server-ip>
   Secondary DNS: <server-ip>
   ```

2. Access AdGuard Home Web UI at `http://<server-ip>:3000`
3. Configure filtering rules and parental controls

### VPN Setup
1. Generate client configurations:
   ```bash
   docker exec wireguard /app/show-peer <peer-number>
   ```

2. Client configs are available in `data/wireguard/peer-configs/`
3. Import config into WireGuard client on your device

### Reverse Proxy Setup
1. Configure domains in Traefik:
   ```yaml
   # In your service labels
   - "traefik.http.routers.myapp.rule=Host(`app.example.com`)"
   - "traefik.http.routers.myapp.tls=true"
   ```

2. Access Traefik dashboard at `http://<server-ip>:8080`

### Monitoring
1. Access Netdata at `http://<server-ip>:19999`
2. View network latency with SmokePing at `http://<server-ip>:8081`
3. Integrate with Prometheus using Node Exporter metrics

## Monitoring and Maintenance

### Health Checks
Run periodic checks:
```bash
# Manual check
./scripts/validate-network.sh

# Automated check (add to cron)
*/15 * * * * /path/to/network-stack/scripts/validate-network.sh >> /var/log/network-health.log
```

### Logs
- **Docker logs**: `docker-compose -f docker-compose.network.yml logs -f`
- **Application logs**: Check individual container logs
- **Access logs**: Monitor for security events

### Updates
1. **Update Docker images**:
   ```bash
   docker-compose -f docker-compose.network.yml pull
   docker-compose -f docker-compose.network.yml up -d
   ```

2. **Backup configurations**:
   ```bash
   tar -czf network-backup-$(date +%Y%m%d).tar.gz config/ data/
   ```

### Backup Strategies
1. **WireGuard configs**: Backup `data/wireguard/config/`
2. **DNS settings**: Backup AdGuard and Unbound configs
3. **SSL certificates**: Backup `data/traefik/letsencrypt/`
4. **Monitor data**: Regular exports of monitoring data

## Troubleshooting

### Common Issues

#### DNS Not Working
- **Check**: `dig @<server-ip> example.com`
- **Solution**: Verify AdGuard/Unbound containers are running

#### VPN Cannot Connect
- **Check**: `docker logs wireguard`
- **Solution**: Verify port forwarding and firewall rules

#### HTTPS Not Working
- **Check**: Traefik logs and certificate status
- **Solution**: Configure proper domain and DNS records

#### High Resource Usage
- **Check**: `docker stats` and Netdata dashboard
- **Solution**: Adjust resource limits in `.env.network`

### Debug Commands
```bash
# Check service status
docker-compose -f docker-compose.network.yml ps

# View logs for specific service
docker logs adguard-home --tail 50

# Test DNS resolution from container
docker exec unbound dig @8.8.8.8 example.com

# Check network connectivity
docker exec adguard-home ping -c 3 google.com

# Monitor resource usage
docker stats --no-stream
```

## Integration

### With Existing Network
1. **Update router DNS settings** to point to the stack
2. **Configure port forwarding** for VPN (51820/UDP)
3. **Set up static IP** for the server
4. **Update firewall rules** to allow necessary traffic

### With Prometheus/Grafana
1. Add these scrape configs to Prometheus:
   ```yaml
   - job_name: 'node'
     static_configs:
       - targets: ['<server-ip>:9100']
   
   - job_name: 'netdata'
     static_configs:
       - targets: ['<server-ip>:19999']
   ```

2. Import Grafana dashboards from `monitoring/grafana/`

### With Backup Systems
- **Configuration backup**: Regular backup of `config/` and `data/`
- **Monitor data backup**: Export Netdata/SmokePing data
- **Certificate backup**: Secure backup of SSL certificates

### With Automation Tools
- **Ansible**: Use Docker modules for deployment
- **Terraform**: Manage as Docker resources
- **Kubernetes**: Convert docker-compose to K8s manifests

## Security Best Practices

1. **Network Security**
   - Use VLAN segmentation
   - Implement proper firewall rules
   - Regular security updates

2. **Access Control**
   - Strong passwords for all services
   - 2FA where available
   - Regular access reviews

3. **Data Protection**
   - Encrypted DNS queries
   - VPN encryption for remote access
   - Secure certificate management

4. **Monitoring**
   - Monitor for unauthorized access
   - Regular security audits
   - Incident response plan

## Performance Optimization

### For High DNS Load
1. **Increase cache sizes** in AdGuard and Unbound
2. **Add more Unbound threads**
3. **Optimize filtering rules**
4. **Use faster upstream DNS**

### For Many VPN Clients
1. **Increase WireGuard resources**
2. **Optimize network routing**
3. **Consider load balancing**
4. **Monitor connection limits**

### For Limited Resources
1. **Disable non-essential services**
2. **Reduce cache sizes**
3. **Lower monitoring frequency**
4. **Use lighter alternatives**

## Contributing

### Adding Features
1. Fork the repository
2. Create a feature branch
3. Implement with tests
4. Update documentation
5. Submit pull request

### Reporting Issues
1. Check existing issues
2. Provide detailed steps
3. Include logs and configs
4. Suggest solutions

### Feature Requests
1. Describe use case
2. Consider complexity
3. Discuss with maintainers
4. Consider contributing

## License

[Specify your license here]

## Support

- **Documentation**: This README and inline comments
- **Issues**: GitHub issue tracker
- **Community**: [Link to community forum]
- **Commercial Support**: [Contact if applicable]

---

*Last updated: $(date)*
*Version: 1.0.0*