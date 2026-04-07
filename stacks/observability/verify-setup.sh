#!/bin/bash

# Verification script for Observability Stack setup
# Checks all configuration files and directories

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "🔍 Verifying Observability Stack Setup..."
echo ""

errors=0
warnings=0

# Function to check file exists
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅${NC} $description: $file"
        return 0
    else
        echo -e "${RED}❌${NC} Missing: $file ($description)"
        errors=$((errors + 1))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅${NC} $description: $dir"
        return 0
    else
        echo -e "${RED}❌${NC} Missing: $dir ($description)"
        errors=$((errors + 1))
        return 1
    fi
}

echo "📋 Checking Docker Compose file..."
check_file "docker-compose.yml" "Docker Compose file"
echo ""

echo "⚙️  Checking configuration files..."
echo ""

echo "  Prometheus:"
check_file "../../config/prometheus/prometheus.yml" "Prometheus config"
check_file "../../config/prometheus/alerts/host.yml" "Host alert rules"
check_file "../../config/prometheus/alerts/containers.yml" "Container alert rules"
check_file "../../config/prometheus/alerts/services.yml" "Service alert rules"

echo ""
echo "  Grafana:"
check_file "../../config/grafana/provisioning/datasources/datasources.yml" "Grafana datasources"
check_file "../../config/grafana/provisioning/dashboards/dashboards.yml" "Dashboard provisioning"
check_dir "../../config/grafana/dashboards" "Dashboards directory"

echo ""
echo "  Loki:"
check_file "../../config/loki/loki-config.yml" "Loki config"
check_file "../../config/loki/promtail-config.yml" "Promtail config"

echo ""
echo "  Tempo:"
check_file "../../config/tempo/tempo-config.yml" "Tempo config"

echo ""
echo "  Alertmanager:"
check_file "../../config/alertmanager/alertmanager.yml" "Alertmanager config"

echo ""
echo "📊 Checking Grafana dashboards..."
dashboard_count=$(ls -1 ../../config/grafana/dashboards/*.json 2>/dev/null | wc -l)
if [ "$dashboard_count" -ge 5 ]; then
    echo -e "${GREEN}✅${NC} Dashboards downloaded: $dashboard_count"
else
    echo -e "${YELLOW}⚠️${NC}  Dashboards: $dashboard_count (expected 5)"
    warnings=$((warnings + 1))
fi

echo ""
echo "📝 Checking setup scripts..."
check_file "../../scripts/download-grafana-dashboards.sh" "Dashboard download script"
check_file "../../scripts/uptime-kuma-setup.sh" "Uptime Kuma setup script"
check_file "./test.sh" "Test script"

echo ""
echo "📄 Checking documentation..."
check_file "./README.md" "README documentation"
check_file "./.env.example" "Environment variables template"

echo ""
echo "================================"
echo "📊 Verification Summary"
echo "================================"
echo ""

if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ All required files present!${NC}"
    
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warnings: $warnings${NC}"
    fi
    
    echo ""
    echo "Next steps:"
    echo "  1. Download dashboards: ../../scripts/download-grafana-dashboards.sh"
    echo "  2. Configure environment: cp .env.example .env && vim .env"
    echo "  3. Start services: docker-compose up -d"
    echo "  4. Run tests: ./test.sh"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Missing $errors required file(s)${NC}"
    
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warnings: $warnings${NC}"
    fi
    
    echo ""
    echo "Please ensure all configuration files are present before proceeding."
    echo ""
    exit 1
fi
