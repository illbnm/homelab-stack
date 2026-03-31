#!/bin/bash
set -e

# 默认操作
OPERATION="check"
DRY_RUN=false
CONFIG_FILE="config/cn-mirrors.yml"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --cn)
      OPERATION="replace"
      shift
      ;;
    --restore)
      OPERATION="restore"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --check)
      OPERATION="check"
      shift
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: $0 [--cn|--restore|--check|--dry-run]"
      exit 1
      ;;
  esac
done

# 检查配置文件是否存在
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "错误: 配置文件 $CONFIG_FILE 不存在"
  exit 1
fi

# 查找所有 docker-compose 文件
COMPOSE_FILES=()
while IFS= read -r -d '' file; do
  COMPOSE_FILES+=("$file")
done < <(find . -maxdepth 2 -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -print0)

if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
  echo "未找到 docker-compose 文件"
  exit 1
fi

echo "找到 ${#COMPOSE_FILES[@]} 个 docker-compose 文件"

# 提取镜像映射
declare -A MIRRORS
while IFS=': ' read -r key value; do
  # 移除前后空白
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  if [[ ! -z "$key" && ! -z "$value" && "$key" != "mirrors" ]]; then
    MIRRORS["$key"]="$value"
  fi
done < <(grep -A 100 "^mirrors:" "$CONFIG_FILE")

# 检测是否需要替换
check_needs_replacement() {
  local file=$1
  for original in "${!MIRRORS[@]}"; do
    if grep -q "$original" "$file"; then
      return 0
    fi
  done
  return 1
}

# 执行替换
perform_replacement() {
  local file=$1
  local replace=true
  
  if [[ "$OPERATION" == "check" ]]; then
    replace=false
  fi
  
  local modified=false
  
  for original in "${!MIRRORS[@]}"; do
    local replacement="${MIRRORS[$original]}"
    
    if grep -q "$original" "$file"; then
      if [[ "$replace" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
          echo "[DRY-RUN] 将在 $file 中替换:"
          echo "  $original → $replacement"
        else
          sed -i.bak "s|${original//./\\.}|${replacement//./\\.}|g" "$file"
          modified=true
          echo "[修改] $file"
        fi
      else
        echo "[检测] $file 需要替换: $original"
      fi
    fi
  done
  
  if [[ "$modified" == true && -f "$file.bak" ]]; then
    rm "$file.bak"
  fi
}

# 执行恢复
perform_restore() {
  local file=$1
  local modified=false
  
  for original in "${!MIRRORS[@]}"; do
    local replacement="${MIRRORS[$original]}"
    
    if grep -q "$replacement" "$file"; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] 将在 $file 中恢复:"
        echo "  $replacement → $original"
      else
        sed -i.bak "s|${replacement//./\\.}|${original//./\\.}|g" "$file"
        modified=true
        echo "[恢复] $file"
      fi
    fi
  done
  
  if [[ "$modified" == true && -f "$file.bak" ]]; then
    rm "$file.bak"
  fi
}

# 处理所有文件
case "$OPERATION" in
  check)
    echo ""
    echo "检查镜像本地化状态..."
    needs_localization=false
    for file in "${COMPOSE_FILES[@]}"; do
      if check_needs_replacement "$file"; then
        needs_localization=true
        break
      fi
    done
    
    if [[ "$needs_localization" == true ]]; then
      echo "✓ 部分文件需要本地化"
    else
      echo "✓ 所有文件已本地化或不需要修改"
    fi
    ;;
  
  replace)
    echo ""
    echo "替换镜像地址为国内源..."
    for file in "${COMPOSE_FILES[@]}"; do
      if check_needs_replacement "$file"; then
        perform_replacement "$file"
      fi
    done
    echo "✓ 替换完成"
    ;;
  
  restore)
    echo ""
    echo "恢复原始镜像地址..."
    for file in "${COMPOSE_FILES[@]}"; do
      perform_restore "$file"
    done
    echo "✓ 恢复完成"
    ;;
esac
