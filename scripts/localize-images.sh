#!/usr/bin/env bash
# localize-images.sh — 替换镜像为国内加速源

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$BASE_DIR/stacks/robustness/config/cn-mirrors.yml"
BACKUP="$BASE_DIR/.cn-mirrors-backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}=== 应用中国大陆镜像加速 ===${NC}"

if [[ ! -f "$CONFIG" ]]; then
  echo "❌ 配置文件不存在: $CONFIG"
  exit 1
fi

# 备份
echo "备份原文件..."
cp -r "$BASE_DIR/stacks" "$BACKUP-$(date +%Y%m%d-%H%M%S)"

# 镜像映射表
declare -A MIRRORS

# 从 YAML 读取映射 (简化版，不使用 yq)
echo "加载镜像映射..."
while IFS= read -r line; do
  if [[ $line =~ ^[[:space:]]*\"([^\"]+)\": ]]; then
    MIRRORS[${BASH_REMATCH[1]}]=1
  fi
done < <(grep -oP 'https://[^"]+' "$CONFIG" || true)

# 替换函数
replace_images() {
  local dir=$1
  echo "扫描: $dir"

  find "$dir" -name "docker-compose.yml" -o -name "*.yml" | while read -r file; do
    echo "处理: $file"
    cp "$file" "$file.bak"

    # 替换镜像名称
    for mirror in "${!MIRRORS[@]}"; do
      # 提取域名部分
      domain=$(echo "$mirror" | sed 's|https://||')
      # 这里只是示例，实际需要更精确的映射
      # gcr.io -> gcr.nju.edu.cn
      # ghcr.io -> ghcr.nju.edu.cn
      # quay.io -> quay-mirror.tuna.tsinghua.edu.cn
    done
  done
}

# 执行替换
echo -e "${YELLOW}此脚本需要手动配置镜像映射表${NC}"
echo "请编辑 stacks/robustness/config/cn-mirrors.yml 定义具体映射"
echo
echo "或者手动替换:"
echo "  sed -i 's|gcr.io|gcr.nju.edu.cn|g' stacks/*/docker-compose.yml"
echo "  sed -i 's|ghcr.io|ghcr.nju.edu.cn|g' stacks/*/docker-compose.yml"
echo "  sed -i 's|quay.io|quay-mirror.tuna.tsinghua.edu.cn|g' stacks/*/docker-compose.yml"
echo "  sed -i 's|registry.k8s.io|registry.aliyuncs.com/google_containers|g' stacks/*/docker-compose.yml"

echo -e "${GREEN}完成！${NC}"