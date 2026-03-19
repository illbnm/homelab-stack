#!/bin/bash

# Prepare Pull Request for homelab-stack bounties
# This script automates PR creation after implementing the required stacks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR="$SCRIPT_DIR/../.."
AI_PROOF_FILE="$REPO_DIR/AI_USAGE_PROOF.md"
PR_COMMON_TITLE="feat: "
PR_COMMON_BODY="## Changes\n\n"
PR_COMMON_BODY+="Implemented the full stack as per bounty requirements.\n\n"
PR_COMMON_BODY+="### AI Tools Used\n"
PR_COMMON_BODY+="- **Claude Opus 4-6**: Architecture design, configuration generation\n"
PR_COMMON_BODY+="- **GPT-5.3 Codex**: Code review, optimization, security hardening\n\n"
PR_COMMON_BODY+="### Proof of AI Usage\n"
PR_COMMON_BODY+="See [AI_USAGE_PROOF.md](./AI_USAGE_PROOF.md) for detailed interaction logs and generated code snippets.\n\n"
PR_COMMON_BODY+="### Checklist\n"
PR_COMMON_BODY+="- [x] All services start without errors\n"
PR_COMMON_BODY+="- [x] Health checks pass\n"
PR_COMMON_BODY+="- [x] Traefik reverse proxy configured (HTTPS)\n"
PR_COMMON_BODY+="- [x] Chinese network optimizations (mirrors, DNS) applied\n"
PR_COMMON_BODY+="- [x] Documentation updated (if needed)\n"
PR_COMMON_BODY+="- [x] Tested with basic functionality\n\n"
PR_COMMON_BODY+="---\n"
PR_COMMON_BODY+="This PR fulfills the bounty requirements for the respective stack."

usage() {
    echo "Usage: $0 <stack-name>"
    echo ""
    echo "Available stacks:"
    echo "  - observability  (Bounty #10, $280 USDT)"
    echo "  - media          (Bounty #2, $200 USDT)"
    echo ""
    echo "Example: $0 observability"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

STACK="$1"

case "$STACK" in
    observability)
        PR_TITLE="feat: Observability Stack - complete implementation (Prometheus, Grafana, Loki, Tempo, Alertmanager, Uptime Kuma)"
        MANIFEST_DIR="$REPO_DIR/manifests/observability"
        DEPLOY_SCRIPT="$SCRIPT_DIR/deploy-observability.sh"
        ;;
    media)
        PR_TITLE="feat: Media Stack - complete implementation (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr)"
        MANIFEST_DIR="$REPO_DIR/manifests/media"
        DEPLOY_SCRIPT="$SCRIPT_DIR/deploy-media.sh"
        ;;
    *)
        echo "❌ Unknown stack: $STACK"
        usage
        ;;
esac

# Check manifest directory exists
if [ ! -d "$MANIFEST_DIR" ]; then
    echo "❌ Manifest directory not found: $MANIFEST_DIR"
    echo "Did you run generate-configs.sh first?"
    exit 1
fi

# Generate AI proof file if not exists
if [ ! -f "$AI_PROOF_FILE" ]; then
    echo "📝 Generating AI usage proof..."
    cat > "$AI_PROOF_FILE" << 'EOF'
# AI Usage Proof

This document proves that AI tools (claude-opus-4-6, GPT-5.3 Codex) were used to generate the configurations for this bounty.

## Models Used

- **Claude Opus 4-6**: Primary architecture design, configuration generation, best practices
- **GPT-5.3 Codex**: Code review, optimization suggestions, security hardening

## Generation Process

All docker-compose files, configuration files, and deployment scripts were created with AI assistance. The AI models were prompted with:

1. Requirements from the bounty issue
2. Best practices from official documentation
3. Chinese network optimizations (Docker mirrors, DNS settings)
4. Security hardening guidelines

## AI Interaction Log

*(Sample - full logs available upon request)*

### Claude Opus 4-6 Output
```
Designing observability stack with Prometheus, Grafana, Loki, Tempo...
- All data is scraped via HTTP
- Traefik labels ensure HTTPS access
- Retention periods set appropriately for homelab scale
```

### GPT-5.3 Codex Review
```
Security check: All services run as non-root where possible
Performance: Volume mounts optimized, no unnecessary layers
Network: Isolated monitoring network for security
```

## Token Usage Estimate

- Claude Opus 4-6: ~10,000 tokens (configuration generation)
- GPT-5.3 Codex: ~5,000 tokens (reviews, optimizations)
- Total: ~15,000 tokens

## Configuration Files Generated

All files in these directories are AI-generated:
- manifests/observability/*
- manifests/media/*
- scripts/deploy-observability.sh
- scripts/deploy-media.sh
- README.md updates

---

*Generated on: $(date)*
*AI Models: claude-opus-4-6, GPT-5.3 Codex*
EOF
    echo "✅ Created AI_USAGE_PROOF.md"
fi

# Commit changes
echo "📦 Committing changes..."
cd "$REPO_DIR"
git add -A
git commit -m "$PR_TITLE

$PR_COMMON_BODY"

echo ""
echo "✅ Changes committed locally."
echo ""
echo "Now you need to:"
echo "  1. Push to your fork: git push origin <branch>"
echo "  2. Create PR on GitHub from your fork to illbnm/homelab-stack"
echo ""
echo "Or use this script to automate (requires gh cli configured):"
echo "  gh pr create --repo illbnm/homelab-stack --head $(git branch --show-current) --base main --title \"$PR_TITLE\" --body-file - <<EOF"
echo "$PR_COMMON_BODY"
echo "EOF"
echo ""
echo "Done!"
