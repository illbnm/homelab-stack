#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Docker registry mirror configurator for CN networks
# Idempotent: safe to run multiple times
# =============================================================================
set -euo pipefail

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_JSON="/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"

# CN mirror list (primary + fallbacks)
CN_MIRRORS=(
  "https://mirror.ccs.tencentyun.com"
  "https://hub-mirror.c.163.com"
  "https://reg-mirror.qiniu.com"
  "https://docker.mirrors.ustc.edu.cn"
  "https://registry.docker-cn.com"
)

echo "=============================================="
echo "  HomeLab Stack — Docker CN Mirror Setup"
echo "=============================================="
echo ""

# Ask user
read -rp "Are you deploying in mainland China? (y/N): " use_cn
if [[ ! "$use_cn" =~ ^[Yy]$ ]]; then
  echo "Skipping CN mirror configuration."
  exit 0
fi

echo ""
echo "Configuring Docker daemon with CN mirrors..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)"
  exit 1
fi

# Backup existing config
if [[ -f "$DAEMON_JSON" ]]; then
  echo "Backing up existing config to $BACKUP_JSON"
  cp "$DAEMON_JSON" "$BACKUP_JSON"
  EXISTING=$(cat "$DAEMON_JSON")
else
  EXISTING="{}"
fi

# Build mirrors JSON array
MIRROR_JSON=$(printf '"%s",' "${CN_MIRRORS[@]}" | sed 's/,$//')

# Merge with existing config using Python (handles existing keys properly)
python3 << EOF
import json, sys

existing = json.loads('''$EXISTING''')
mirrors = [$MIRROR_JSON]

existing['registry-mirrors'] = mirrors
existing.setdefault('log-driver', 'json-file')
existing.setdefault('log-opts', {'max-size': '10m', 'max-file': '3'})

with open('$DAEMON_JSON', 'w') as f:
    json.dump(existing, f, indent=2)

print("Written to $DAEMON_JSON")
print("Registry mirrors configured:")
for m in mirrors:
    print(f"  - {m}")
EOF

echo ""
echo "Validating config..."
if python3 -c "import json; json.load(open('$DAEMON_JSON'))" 2>/dev/null; then
  echo "✅ Config valid"
else
  echo "❌ Invalid JSON — restoring backup"
  [[ -f "$BACKUP_JSON" ]] && cp "$BACKUP_JSON" "$DAEMON_JSON"
  exit 1
fi

echo ""
read -rp "Restart Docker daemon now? (Y/n): " restart_docker
if [[ ! "$restart_docker" =~ ^[Nn]$ ]]; then
  echo "Restarting Docker..."
  systemctl restart docker
  echo "✅ Docker restarted"
  echo ""
  echo "Testing mirror (pulling hello-world)..."
  docker pull hello-world:latest 2>&1 | grep -E "Pull complete|already|Status" || true
fi

echo ""
echo "✅ CN mirror setup complete!"
echo "   Run 'docker info | grep -A5 Registry' to verify"
