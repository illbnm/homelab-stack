#!/bin/bash

# Storage Stack Setup Script
# This script sets up the complete storage stack with NFS, Syncthing, and MinIO

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/config"
DATA_DIR="$PROJECT_ROOT/data"
LOG_DIR="$PROJECT_ROOT/logs"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        # Try docker compose (v2)
        if ! docker compose version &> /dev/null; then
            print_error "Docker Compose is not installed. Please install Docker Compose first."
            exit 1
        fi
        DOCKER_COMPOSE_CMD="docker compose"
    else
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
    
    # Check available ports
    local ports=(2049 111 8384 22000 21027 9000 9001 9100 8080)
    for port in "${ports[@]}"; do
        if netstat -tuln | grep ":$port " > /dev/null; then
            print_warning "Port $port is already in use. This may cause conflicts."
        fi
    done
    
    print_status "Prerequisites check passed."
}

# Function to setup directories
setup_directories() {
    print_status "Setting up directories..."
    
    mkdir -p "$DATA_DIR"/{nfs,syncthing/config,syncthing/sync,minio}
    mkdir -p "$CONFIG_DIR"/{nfs,syncthing,minio}
    mkdir -p "$LOG_DIR"
    mkdir -p "$PROJECT_ROOT/backup"
    mkdir -p "$PROJECT_ROOT/monitoring"
    
    # Set proper permissions
    chmod 755 "$DATA_DIR"
    chmod -R 755 "$CONFIG_DIR"
    
    print_status "Directories created successfully."
}

# Function to generate configuration files
generate_configs() {
    print_status "Generating configuration files..."
    
    # Generate NFS exports file
    cat > "$CONFIG_DIR/nfs/exports" << EOF
# NFS Exports Configuration
# Generated on $(date)

# Main data directory
/data ${NFS_ALLOWED_NETWORKS:-192.168.1.0/24}(${NFS_EXPORT_OPTIONS:-rw,sync,no_subtree_check,no_root_squash})

# Additional exports can be added below
# /data/media ${NFS_ALLOWED_NETWORKS:-192.168.1.0/24}(ro,sync,no_subtree_check)
EOF
    
    # Generate Syncthing config template
    cat > "$CONFIG_DIR/syncthing/config.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration version="35">
    <folder id="default" label="Default Sync" path="/var/syncthing/Sync" type="sendreceive" rescanIntervalS="60" fsWatcherEnabled="true" fsWatcherDelayS="10" ignorePerms="false" autoNormalize="true">
        <device id="SELF"></device>
        <minDiskFree unit="%">1</minDiskFree>
        <versioning type="simple">
            <cleanupIntervalS>3600</cleanupIntervalS>
            <params>
                <keep>10</keep>
            </params>
        </versioning>
        <copiers>0</copiers>
        <pullerMaxPendingKiB>0</pullerMaxPendingKiB>
        <hashers>0</hashers>
        <order>random</order>
        <ignoreDelete>false</ignoreDelete>
        <scanProgressIntervalS>0</scanProgressIntervalS>
        <pullerPauseS>0</pullerPauseS>
        <maxConflicts>10</maxConflicts>
        <disableSparseFiles>false</disableSparseFiles>
        <disableTempIndexes>false</disableTempIndexes>
        <paused>false</paused>
        <weakHashThresholdPct>25</weakHashThresholdPct>
        <markerName>.stfolder</markerName>
        <useLargeBlocks>false</useLargeBlocks>
        <jit>false</jit>
        <caseSensitiveFS>true</caseSensitiveFS>
    </folder>
    <device id="SELF" name="Local Syncthing" compression="metadata" introducer="false" skipIntroductionRemovals="false" introducedBy="">
        <address>dynamic</address>
        <paused>false</paused>
        <autoAcceptFolders>false</autoAcceptFolders>
        <maxSendKbps>0</maxSendKbps>
        <maxRecvKbps>0</maxRecvKbps>
        <maxRequestKiB>0</maxRequestKiB>
    </device>
    <gui enabled="true" tls="false" debugging="false">
        <address>0.0.0.0:8384</address>
        <apikey>${SYNCTHING_GUI_API_KEY:-change_me}</apikey>
        <theme>default</theme>
    </gui>
    <ldap></ldap>
    <options>
        <listenAddress>default</listenAddress>
        <globalAnnounceServer>default</globalAnnounceServer>
        <globalAnnounceEnabled>true</globalAnnounceEnabled>
        <localAnnounceEnabled>true</localAnnounceEnabled>
        <maxSendKbps>0</maxSendKbps>
        <maxRecvKbps>0</maxRecvKbps>
        <reconnectionIntervalS>60</reconnectionIntervalS>
        <relaysEnabled>true</relaysEnabled>
        <relayReconnectIntervalM>10</relayReconnectIntervalM>
        <startBrowser>false</startBrowser>
        <natEnabled>true</natEnabled>
        <natLeaseMinutes>60</natLeaseMinutes>
        <natRenewalMinutes>30</natRenewalMinutes>
        <natTimeoutSeconds>10</natTimeoutSeconds>
        <urAccepted>0</urAccepted>
        <urSeen>0</urSeen>
        <urUniqueID></urUniqueID>
        <urURL></urURL>
        <urPostInsecurely>false</urPostInsecurely>
        <urInitialDelayS>1800</urInitialDelayS>
        <restartOnWakeup>true</restartOnWakeup>
        <autoUpgradeIntervalH>12</autoUpgradeIntervalH>
        <upgradeToPreReleases>false</upgradeToPreReleases>
        <keepTemporariesH>24</keepTemporariesH>
        <cacheIgnoredFiles>false</cacheIgnoredFiles>
        <progressUpdateIntervalS>5</progressUpdateIntervalS>
        <limitBandwidthInLan>false</limitBandwidthInLan>
        <minHomeDiskFree unit="%">1</minHomeDiskFree>
        <releasesURL></releasesURL>
        <alwaysLocalNets></alwaysLocalNets>
        <overwriteRemoteDeviceNamesOnConnect>false</overwriteRemoteDeviceNamesOnConnect>
        <tempIndexMinBlocks>10</tempIndexMinBlocks>
        <trafficClass>0</trafficClass>
        <defaultFolderPath>${SYNCTHING_DEFAULT_FOLDER_PATH:-/var/syncthing/Sync}</defaultFolderPath>
        <setLowPriority>true</setLowPriority>
        <maxFolderConcurrency>0</maxFolderConcurrency>
        <crashReportingEnabled>false</crashReportingEnabled>
    </options>
</configuration>
EOF
    
    # Generate MinIO config
    cat > "$CONFIG_DIR/minio/config.json" << EOF
{
    "version": "1",
    "credential": {
        "accessKey": "\${MINIO_ROOT_USER}",
        "secretKey": "\${MINIO_ROOT_PASSWORD}"
    },
    "region": "us-east-1",
    "browser": "on",
    "domain": "",
    "storageclass": {
        "standard": "",
        "rrs": ""
    },
    "cache": {
        "drives": [],
        "expiry": 90,
        "exclude": []
    },
    "notify": {},
    "logger": {
        "console": {
            "enable": true
        },
        "file": {
            "enable": true,
            "filename": "/data/minio.log"
        }
    }
}
EOF
    
    print_status "Configuration files generated."
}

# Function to start the stack
start_stack() {
    print_status "Starting Storage Stack..."
    
    cd "$PROJECT_ROOT"
    
    # Load environment variables
    if [ -f .env.storage ]; then
        export $(grep -v '^#' .env.storage | xargs)
    fi
    
    # Start services
    $DOCKER_COMPOSE_CMD -f docker-compose.storage.yml up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 10
    
    # Check service status
    check_service_health
    
    print_status "Storage Stack started successfully!"
}

# Function to check service health
check_service_health() {
    print_status "Checking service health..."
    
    local services=("nfs-server" "syncthing" "minio")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --format "{{.Status}}" | grep -q "healthy"; then
            print_status "$service: Healthy"
        else
            print_warning "$service: Not healthy (check logs with 'docker logs $service')"
            all_healthy=false
        fi
    done
    
    if $all_healthy; then
        print_status "All services are healthy!"
    else
        print_warning "Some services may need attention. Check logs for details."
    fi
}

# Function to display access information
display_access_info() {
    print_status "Storage Stack Access Information:"
    echo ""
    echo "=== NFS Server ==="
    echo "Server: $(hostname -I | awk '{print $1}')"
    echo "Share: /data"
    echo "Mount command: sudo mount -t nfs $(hostname -I | awk '{print $1}'):/data /mnt/nfs"
    echo ""
    echo "=== Syncthing ==="
    echo "Web UI: http://$(hostname -I | awk '{print $1}'):8384"
    echo "API Key: Check config/syncthing/config.xml"
    echo ""
    echo "=== MinIO ==="
    echo "API: http://$(hostname -I | awk '{print $1}'):9000"
    echo "Console: http://$(hostname -I | awk '{print $1}'):9001"
    echo "Access Key: ${MINIO_ROOT_USER:-admin}"
    echo "Secret Key: ${MINIO_ROOT_PASSWORD:-changeme123}"
    echo ""
    echo "=== Monitoring ==="
    echo "Node Exporter: http://$(hostname -I | awk '{print $1}'):9100"
    echo "cAdvisor: http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Change all default passwords"
    echo "2. Configure firewall rules"
    echo "3. Set up backups"
    echo "4. Integrate with your monitoring system"
}

# Main execution
main() {
    print_status "Starting Storage Stack Setup"
    echo ""
    
    check_prerequisites
    setup_directories
    generate_configs
    start_stack
    display_access_info
    
    echo ""
    print_status "Setup complete! Logs are available in: $LOG_DIR"
    print_status "To stop the stack: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.storage.yml down"
    print_status "To view logs: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.storage.yml logs -f"
}

# Run main function
main "$@"