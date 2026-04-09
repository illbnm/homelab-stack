# Enterprise Storage Stack

A complete, production-ready storage solution for homelabs and small businesses, featuring NFS for file sharing, Syncthing for synchronization, and MinIO for object storage.

## Features

### 🗂️ Multi-Protocol Storage
- **NFS Server**: High-performance network file sharing
- **Syncthing**: Secure, decentralized file synchronization  
- **MinIO**: S3-compatible object storage with web console

### 🔒 Enterprise Security
- Network isolation with dedicated Docker network
- TLS encryption support for all services
- Role-based access control
- Comprehensive audit logging

### 📊 Complete Monitoring
- Prometheus metrics for all services
- Grafana dashboards for storage analytics
- Health checks and automated alerts
- Performance monitoring and capacity planning

### ⚡ Production Ready
- Health checks and automatic restarts
- Resource limits and optimization
- Backup and recovery procedures
- High availability configuration

## Quick Start

### Prerequisites
- Docker and Docker Compose
- 2GB RAM minimum, 4GB recommended
- 20GB disk space minimum

### Installation

1. **Clone or copy the storage stack files**
   ```bash
   git clone <repository-url>
   cd storage-stack
   ```

2. **Configure environment variables**
   ```bash
   cp .env.storage.example .env.storage
   # Edit .env.storage with your settings
   ```

3. **Run the setup script**
   ```bash
   chmod +x scripts/setup-storage.sh
   ./scripts/setup-storage.sh
   ```

4. **Verify the installation**
   ```bash
   ./scripts/validate-storage.sh
   ```

## Service Details

### NFS Server
- **Purpose**: Network file sharing for Linux/Unix systems
- **Ports**: 2049 (NFS), 111 (RPC)
- **Mount Command**: `sudo mount -t nfs <server-ip>:/data /mnt/nfs`
- **Configuration**: `config/nfs/exports`

### Syncthing
- **Purpose**: Secure file synchronization across devices
- **Web UI**: http://<server-ip>:8384
- **API**: REST API with configurable API key
- **Configuration**: `config/syncthing/config.xml`

### MinIO
- **Purpose**: S3-compatible object storage
- **API**: http://<server-ip>:9000
- **Console**: http://<server-ip>:9001
- **Default Buckets**: backups, media, documents, archives
- **Configuration**: `config/minio/config.json`

### Monitoring
- **Node Exporter**: http://<server-ip>:9100/metrics
- **cAdvisor**: http://<server-ip>:8080/metrics
- **Logs**: `logs/` directory with rotated logs

## Configuration

### Environment Variables
Key environment variables in `.env.storage`:

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_ROOT_USER` | MinIO admin username | `admin` |
| `MINIO_ROOT_PASSWORD` | MinIO admin password | `changeme123` |
| `NFS_ALLOWED_NETWORKS` | Networks allowed to access NFS | `192.168.1.0/24` |
| `SYNCTHING_GUI_API_KEY` | Syncthing API key | Auto-generated |
| `STORAGE_NETWORK_SUBNET` | Internal Docker network | `172.20.0.0/24` |

### Security Configuration
1. **Change all default passwords** in `.env.storage`
2. **Configure firewall rules** for exposed ports
3. **Enable TLS** by setting `ENABLE_TLS=true`
4. **Restrict NFS access** to trusted networks
5. **Use strong API keys** for Syncthing

### Performance Tuning
Adjust these variables based on your hardware:

```bash
# CPU limits (cores)
NFS_CPU_LIMIT=1.0
MINIO_CPU_LIMIT=2.0
SYNCTHING_CPU_LIMIT=0.5

# Memory limits
NFS_MEMORY_LIMIT=512M
MINIO_MEMORY_LIMIT=1G
SYNCTHING_MEMORY_LIMIT=256M

# Cache sizes
NFS_CACHE_SIZE=128m
MINIO_CACHE_SIZE=1G
```

## Usage Examples

### Basic File Sharing
1. Mount NFS share on client:
   ```bash
   sudo mkdir /mnt/nfs
   sudo mount -t nfs <server-ip>:/data /mnt/nfs
   ```

2. Add to `/etc/fstab` for automatic mounting:
   ```
   <server-ip>:/data  /mnt/nfs  nfs  defaults  0  0
   ```

### File Synchronization
1. Access Syncthing Web UI at `http://<server-ip>:8384`
2. Add new devices using device IDs
3. Create folders and configure sync rules
4. Enable versioning for file recovery

### Object Storage
1. Access MinIO Console at `http://<server-ip>:9001`
2. Login with admin credentials
3. Create buckets and set policies
4. Use S3-compatible tools:
   ```bash
   # Using AWS CLI
   aws --endpoint-url http://<server-ip>:9000 s3 ls
   
   # Using MinIO client
   mc alias set mystorage http://<server-ip>:9000 admin password
   mc ls mystorage
   ```

## Monitoring and Maintenance

### Health Checks
Run periodic health checks:
```bash
# Manual check
./scripts/validate-storage.sh

# Automated check (add to cron)
*/15 * * * * /path/to/storage-stack/scripts/validate-storage.sh >> /var/log/storage-health.log
```

### Logs
- **Docker logs**: `docker-compose -f docker-compose.storage.yml logs -f`
- **Application logs**: `logs/` directory
- **Access logs**: Monitor for security events

### Backups
1. **Configuration backup** (daily):
   ```bash
   ./scripts/backup-config.sh
   ```

2. **Data backup strategies**:
   - Use MinIO's built-in replication
   - Sync important data to another Syncthing instance
   - Regular NFS snapshot backups

### Updates
1. **Update Docker images**:
   ```bash
   docker-compose -f docker-compose.storage.yml pull
   docker-compose -f docker-compose.storage.yml up -d
   ```

2. **Check for breaking changes** in release notes
3. **Test updates** in staging before production

## Troubleshooting

### Common Issues

#### NFS Mount Fails
- **Check**: `showmount -e <server-ip>`
- **Solution**: Verify firewall rules and NFS export configuration

#### Syncthing Not Syncing
- **Check**: Web UI device status and folder errors
- **Solution**: Ensure devices are connected and folders shared

#### MinIO Cannot Create Buckets
- **Check**: MinIO logs with `docker logs minio`
- **Solution**: Verify credentials and disk permissions

#### High Resource Usage
- **Check**: `docker stats` and monitoring dashboards
- **Solution**: Adjust resource limits in `.env.storage`

### Debug Commands
```bash
# View all container logs
docker-compose -f docker-compose.storage.yml logs

# Check specific service
docker logs nfs-server --tail 50

# Test connectivity
docker exec nfs-server ping google.com

# Check disk usage
docker exec nfs-server df -h

# View resource usage
docker stats --no-stream
```

## Integration

### With Prometheus/Grafana
1. Add these scrape configs to Prometheus:
   ```yaml
   - job_name: 'node'
     static_configs:
       - targets: ['<server-ip>:9100']
   
   - job_name: 'cadvisor'
     static_configs:
       - targets: ['<server-ip>:8080']
   ```

2. Import Grafana dashboards from `monitoring/grafana/`

### With Backup Systems
- **MinIO**: Use `mc mirror` for S3-to-S3 backups
- **Syncthing**: Built-in versioning and external backup folders
- **NFS**: Use `rsync` or `tar` for file-level backups

### With Automation Tools
- **Ansible**: Use Docker modules for deployment
- **Terraform**: Manage as Docker resources
- **Kubernetes**: Convert docker-compose to K8s manifests

## Security Best Practices

1. **Network Security**
   - Use dedicated VLAN for storage traffic
   - Implement firewall rules
   - Consider VPN for remote access

2. **Access Control**
   - Use strong, unique passwords
   - Implement 2FA where possible
   - Regular access review

3. **Data Protection**
   - Enable encryption at rest
   - Regular backups to offsite location
   - Data classification and retention policies

4. **Monitoring**
   - Monitor for unauthorized access attempts
   - Regular security audits
   - Incident response plan

## Performance Optimization

### For High Throughput
1. **Use SSD storage** for MinIO and Syncthing
2. **Enable MinIO cache** for frequently accessed objects
3. **Optimize NFS settings** for your workload
4. **Increase memory limits** for caching

### For Many Small Files
1. **Reduce Syncthing rescan intervals**
2. **Optimize MinIO small object handling**
3. **Use NFS with noatime option**
4. **Consider file system tuning**

### For Limited Resources
1. **Reduce cache sizes**
2. **Lower CPU limits**
3. **Disable non-essential features**
4. **Use resource prioritization**

## Contributing

### Adding New Features
1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Update documentation
5. Submit pull request

### Reporting Issues
1. Check existing issues
2. Provide detailed reproduction steps
3. Include logs and configuration
4. Suggest possible solutions

### Feature Requests
1. Describe use case and benefits
2. Consider implementation complexity
3. Discuss with maintainers
4. Consider contributing implementation

## License

[Specify your license here]

## Support

- **Documentation**: This README and inline comments
- **Issues**: GitHub issue tracker
- **Community**: [Link to community forum or chat]
- **Commercial Support**: [Contact information if applicable]

---

*Last updated: $(date)*
*Version: 1.0.0*