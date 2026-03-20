#!/bin/bash
# HomeLab Stack - PR Submission Script for Issue #6 (AI Stack)
# Bounty: $220 USDT

set -e

GITHUB_USER="zhuzhushiwojia"
REPO="homelab-stack"
BRANCH="feature/ai-stack-complete"
ISSUE="6"

echo "🦞 HomeLab Stack - Issue #6 AI Stack PR Submission"
echo "=================================================="

# Check if running in homelab-stack directory
if [ ! -f "homelab.md" ]; then
    echo "❌ Error: Please run this script from homelab-stack directory"
    exit 1
fi

# Configure git
git config --global user.name "zhuzhushiwojia"
git config --global user.email "zhuzhushiwojia@qq.com"

# Create and checkout feature branch
echo "📦 Creating feature branch..."
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

# Add AI Stack files
echo "📝 Adding AI Stack files..."
git add stacks/ai/
git commit -m "feat: Add AI Stack with Ollama + Open WebUI + Stable Diffusion (Issue #6)"

# Push to GitHub
echo "🚀 Pushing to GitHub..."
git push -u origin "$BRANCH"

# Create PR using GitHub CLI or API
echo "📋 Creating Pull Request..."

PR_TITLE="feat: Add AI Stack - Ollama + Open WebUI + Stable Diffusion (Issue #6)"
PR_BODY="## 🎯 Implements Issue #6 - AI Stack (\$220 USDT Bounty)

This PR adds a complete AI inference stack for the HomeLab environment.

## 📦 Included Services

### 1. Ollama - Local LLM Inference
- **Image**: ollama/ollama:0.3.14
- **Port**: 11434
- **Access**: https://ollama.\${DOMAIN}
- **Features**:
  - Run open-source LLMs locally (Llama 3, Mistral, Qwen, etc.)
  - RESTful API
  - Automatic model management
  - GPU acceleration support (optional)

### 2. Open WebUI - AI Chat Interface
- **Image**: ghcr.io/open-webui/open-webui:v0.3.35
- **Port**: 8080
- **Access**: https://ai.\${DOMAIN}
- **Features**:
  - ChatGPT-like UI
  - Multi-model support
  - Conversation history
  - Chinese language support
  - File upload and analysis
  - RAG support

### 3. Stable Diffusion WebUI (Optional)
- **Image**: ghcr.io/neggles/sd-webui-docker:latest
- **Port**: 7860
- **Access**: https://sd.\${DOMAIN}
- **Features**:
  - AI image generation
  - Text-to-image / Image-to-image
  - Model management
  - Extension support

## ✅ Acceptance Criteria

- [x] Docker Compose configuration
- [x] Traefik integration with HTTPS
- [x] Health checks configured
- [x] Data persistence
- [x] Complete README documentation
- [x] Environment variable examples
- [x] GPU acceleration support (optional)
- [x] Resource requirements documented
- [x] Troubleshooting guide

## 🚀 Quick Start

\`\`\`bash
cd stacks/ai
docker compose up -d

# Download models
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull qwen2.5:7b

# Access Open WebUI
# https://ai.yourdomain.com
\`\`\`

## 📊 Resource Requirements

| Service | CPU | Memory | Storage | GPU |
|---------|-----|--------|---------|-----|
| Ollama | 2-4 cores | 4-8GB | 10-50GB | Recommended |
| Open WebUI | 1-2 cores | 2-4GB | 5GB | No |
| Stable Diffusion | 4-8 cores | 8-16GB | 20-100GB | Required |

**Minimum**: 4-core CPU, 8GB RAM, 50GB storage  
**Recommended**: 8-core CPU, 16GB RAM, 100GB storage, NVIDIA GPU

## 🔗 Links

- Issue: https://github.com/$GITHUB_USER/$REPO/issues/$ISSUE
- Ollama Docs: https://ollama.com/
- Open WebUI Docs: https://docs.openwebui.com/

## 💰 Payment

**USDT-TRC20**: \`TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1\`

Ready for review! 🚀
"

# Try GitHub CLI first, fallback to API
if command -v gh &> /dev/null; then
    gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main --head "$BRANCH"
else
    # Use GitHub API
    PR_DATA=$(cat <<EOF
{
  "title": "$PR_TITLE",
  "body": "$(echo "$PR_BODY" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')",
  "base": "main",
  "head": "$BRANCH"
}
EOF
)
    
    curl -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/$GITHUB_USER/$REPO/pulls \
      -d "$PR_DATA"
fi

echo ""
echo "✅ PR created successfully!"
echo "📝 PR URL: https://github.com/$GITHUB_USER/$REPO/pulls"
echo ""
echo "💰 Bounty: \$220 USDT"
echo "💳 Payment Address: TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1"
