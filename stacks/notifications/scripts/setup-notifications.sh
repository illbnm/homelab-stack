#!/bin/bash

# Notifications Stack Setup Script
# Sets up Gotify, NTFY, Apprise, and optional monitoring

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

check_prerequisites() {
    print_status "Checking prerequisites..."
    command -v docker >/dev/null 2>&1 || { print_error "Docker required"; exit 1; }
    
    if command -v docker-compose >/dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose required"; exit 1
    fi
    
    # Check port availability
    local ports=(8080 8081 8000 3002 9091 9093 6379 5432 8082 25 587)
    for port in "${ports[@]}"; do
        if netstat -tuln | grep ":$port " >/dev/null; then
            print_warning "Port $port is already in use"
        fi
    done
}

setup_directories() {
    print_status "Setting up directories..."
    
    mkdir -p "$PROJECT_ROOT"/data/{notification-server,ntfy/cache,apprise,grafana,prometheus,alertmanager,redis,postgres,webhook/logs,smtp}
    mkdir -p "$PROJECT_ROOT"/config/{notification-server,ntfy,apprise,grafana,prometheus,alertmanager,webhook}
    mkdir -p "$PROJECT_ROOT"/logs
    
    chmod -R 755 "$PROJECT_ROOT"/config
    chmod -R 755 "$PROJECT_ROOT"/data
    
    print_status "Directories created successfully."
}

generate_configs() {
    print_status "Generating configuration files..."
    
    # Gotify configuration
    cat > "$PROJECT_ROOT/config/notification-server/config.yml" << 'EOF'
server:
  listenaddr: "0.0.0.0"
  port: 80
  ssl:
    enabled: false
    redirecttohttps: false
    listenaddr: "0.0.0.0"
    port: 443
    certfile: ""
    certkey: ""
  responseheaders:
    Access-Control-Allow-Origin: "*"
    Access-Control-Allow-Methods: "GET,POST,OPTIONS"
    Access-Control-Allow-Headers: "*"
  stream:
    allowedorigins:
      - "*"
    pingperiodseconds: 45
  keepaliveperiodseconds: 0
database:
  dialect: sqlite3
  connection: /etc/gotify/data/gotify.db
  automigrate: true
defaultuser:
  name: admin
  pass: changeme
passstrength: 10
uploadedimagesdir: /etc/gotify/data/images
pluginsdir: /etc/gotify/plugins
cors:
  alloworigins:
    - "*"
  allowmethods:
    - "GET"
    - "POST"
    - "OPTIONS"
  allowheaders:
    - "Authorization"
    - "Content-Type"
  maxage: 86400
EOF
    
    # NTFY configuration
    cat > "$PROJECT_ROOT/config/ntfy/server.yml" << 'EOF'
# ntfy server configuration
base-url: "http://localhost:8081"
cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "12h"
auth-file: "/etc/ntfy/user.db"
auth-default-access: "read-write"
behind-proxy: false
enable-signup: false
enable-login: false
enable-reservations: false
enable-cors: true
attachment-cache-dir: "/var/cache/ntfy/attachments"
attachment-total-size-limit: "5G"
attachment-file-size-limit: "15M"
attachment-expiry-duration: "3h"
keepalive-interval: "45s"
manager-interval: "1m"
global-topic-limit: 1000
visitor-subscription-limit: 30
visitor-request-limit-burst: 60
visitor-request-limit-replenish: "10s"
visitor-message-daily-limit: 100
visitor-email-limit-burst: 16
visitor-email-limit-replenish: "1h"
EOF
    
    # Apprise configuration
    cat > "$PROJECT_ROOT/config/apprise/apprise.yml" << 'EOF'
# Apprise configuration
urls:
  - "gotify://${NOTIFICATION_ADMIN_USER}:${NOTIFICATION_ADMIN_PASSWORD}@notification-server/message?priority=normal"
  - "ntfy://localhost:8081/alerts?priority=high"
  - "json://localhost:8082/webhook"

# Tag assignments
tag:
  # System alerts
  system:
    - "gotify://${NOTIFICATION_ADMIN_USER}:${NOTIFICATION_ADMIN_PASSWORD}@notification-server/system?priority=high"
    - "ntfy://localhost:8081/system"
  
  # User notifications
  users:
    - "gotify://${NOTIFICATION_ADMIN_USER}:${NOTIFICATION_ADMIN_PASSWORD}@notification-server/users?priority=normal"
  
  # Critical alerts
  critical:
    - "gotify://${NOTIFICATION_ADMIN_USER}:${NOTIFICATION_ADMIN_PASSWORD}@notification-server/critical?priority=max"
    - "ntfy://localhost:8081/critical?priority=max"

# Default tags if none specified
default: system
EOF
    
    # Prometheus configuration
    cat > "$PROJECT_ROOT/config/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'notification-server'
    static_configs:
      - targets: ['notification-server:80']

  - job_name: 'ntfy'
    static_configs:
      - targets: ['ntfy:80']

  - job_name: 'apprise-api'
    static_configs:
      - targets: ['apprise-api:8000']
EOF
    
    # AlertManager configuration
    cat > "$PROJECT_ROOT/config/alertmanager/alertmanager.yml" << 'EOF'
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://notification-server/message?token=YOUR_TOKEN'
        send_resolved: true
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF
    
    # Webhook receiver configuration
    cat > "$PROJECT_ROOT/config/webhook/app.py" << 'EOF'
from flask import Flask, request, jsonify
import hmac
import hashlib
import json
import os

app = Flask(__name__)
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'changeme')

def verify_signature(payload, signature):
    """Verify webhook signature"""
    expected = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)

@app.route('/webhook/<channel>', methods=['POST'])
def webhook_receiver(channel):
    """Receive webhook notifications"""
    signature = request.headers.get('X-Signature')
    payload = request.get_data()
    
    if not verify_signature(payload, signature):
        return jsonify({'error': 'Invalid signature'}), 401
    
    try:
        data = request.json
        # Process notification based on channel
        # In production, this would forward to appropriate notification service
        print(f"Received notification for channel {channel}: {data}")
        return jsonify({'status': 'received'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF
    
    # Create requirements file for webhook
    cat > "$PROJECT_ROOT/config/webhook/requirements.txt" << 'EOF'
Flask==2.3.3
gunicorn==20.1.0
EOF
    
    print_status "Configuration files generated."
}

start_services() {
    print_status "Starting Notifications Stack..."
    
    cd "$PROJECT_ROOT"
    
    # Load environment variables
    if [ -f .env.notifications ]; then
        export $(grep -v '^#' .env.notifications | xargs)
    fi
    
    # Start core services
    $DOCKER_COMPOSE_CMD -f docker-compose.notifications.yml up -d \
        notification-server \
        ntfy \
        apprise-api \
        webhook-receiver
    
    print_status "Waiting for services to start..."
    sleep 20
    
    # Check service status
    check_service_health
    
    print_status "Core notification services started successfully!"
}

check_service_health() {
    print_status "Checking service health..."
    
    local services=("notification-server" "ntfy" "apprise-api" "webhook-receiver")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --format "{{.Status}}" | grep -q "Up"; then
            print_status "$service: Running"
        else
            print_warning "$service: Not running (check logs with 'docker logs $service')"
            all_healthy=false
        fi
    done
    
    if $all_healthy; then
        print_status "All core services are running!"
    else
        print_warning "Some services may need attention. Check logs for details."
    fi
}

display_access_info() {
    local ip=$(hostname -I | awk '{print $1}')
    
    cat << EOF

=== Notifications Stack Installation Complete ===

Core Services:
- Gotify (Notification Server): http://$ip:8080
  Username: admin
  Password: changeme (CHANGE THIS!)

- NTFY (Pub/Sub Notifications): http://$ip:8081
  Topics: /alerts, /system, /critical

- Apprise-API (Multi-platform): http://$ip:8000
  API Docs: http://$ip:8000/docs

- Webhook Receiver: http://$ip:8082
  Endpoint: /webhook/<channel>

Optional Services (if enabled):
- Grafana: http://$ip:3002
- Prometheus: http://$ip:9091
- AlertManager: http://$ip:9093
- Redis: $ip:6379
- PostgreSQL: $ip:5432

Configuration:
- Config files: $PROJECT_ROOT/config/
- Data storage: $PROJECT_ROOT/data/
- Logs: $PROJECT_ROOT/logs/

Next Steps:
1. Change all default passwords in .env.notifications
2. Configure notification channels (Telegram, Slack, etc.)
3. Set up monitoring and alerting
4. Integrate with your applications
5. Test notification delivery

API Examples:
# Send notification via Gotify
curl -X POST "http://$ip:8080/message" \\
  -H "X-Gotify-Key: YOUR_APP_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{"message": "Test notification", "title": "Test", "priority": 5}'

# Send notification via NTFY
curl -d "Test message" "http://$ip:8081/alerts"

# Send notification via Apprise
curl -X POST "http://$ip:8000/notify" \\
  -H "Content-Type: application/json" \\
  -d '{"urls": "gotify://admin:changeme@notification-server/test", "title": "Test", "body": "Test message"}'

Troubleshooting:
- Check logs: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.notifications.yml logs -f
- Restart services: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.notifications.yml restart
- Stop services: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.notifications.yml down

EOF
}

main() {
    print_status "Starting Notifications Stack Setup"
    echo ""
    
    check_prerequisites
    setup_directories
    generate_configs
    start_services
    display_access_info
    
    print_status "Setup complete!"
    print_status "Remember to change all default passwords and configure notification channels."
}

main "$@"