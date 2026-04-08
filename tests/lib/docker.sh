#!/usr/bin/env bash
# HomeLab Stack — Docker 工具函数

set -euo pipefail

# 等待容器健康
wait_for_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))
  
  while [[ $(date +%s) -lt $end_time ]]; do
    if docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null | grep -q "healthy"; then
      return 0
    fi
    sleep 2
  done
  
  return 1
}

# 等待容器运行
wait_for_running() {
  local name="$1"
  local timeout="${2:-30}"
  
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))
  
  while [[ $(date +%s) -lt $end_time ]]; do
    if docker ps --filter "name=$name" --filter "status=running" | grep -q "$name"; then
      return 0
    fi
    sleep 2
  done
  
  return 1
}

# 获取容器状态
get_container_status() {
  local name="$1"
  docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "not found"
}

# 获取容器 IP
get_container_ip() {
  local name="$1"
  docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null || echo ""
}

# 重启容器
restart_container() {
  local name="$1"
  docker restart "$name" 2>/dev/null
}

# 停止容器
stop_container() {
  local name="$1"
  docker stop "$name" 2>/dev/null
}

# 启动容器
start_container() {
  local name="$1"
  docker start "$name" 2>/dev/null
}
