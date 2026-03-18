#!/usr/bin/env bash

# Jellyfin 硬件检测脚本
# 自动检测可用硬件加速并输出推荐的 Docker 环境变量
#
# 用法: ./jellyfin-hw-detection.sh
# 输出可以直接复制到 docker-compose.yml 的 environment 部分

set -euo pipefail

echo "=== Jellyfin 硬件加速检测 ==="
echo ""

# 检测 NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo "✅ 检测到 NVIDIA GPU:"
    nvidia-smi --query-gpu=name --format=csv,noheader | head -1
    echo ""
    echo "推荐配置:"
    echo "  - 环境变量:"
    echo "      JELLYFIN_HW_DEVICE=nvenc"
    echo "      JELLYFIN_HW_DEVICE_TYPE=cuda"
    echo "      NVIDIA_VISIBLE_DEVICES=all"
    echo "      NVIDIA_DRIVER_CAPABILITIES=compute,video,graphics"
    echo "  - 运行前提: 宿主机已安装 nvidia-container-toolkit"
    echo ""
fi

# 检测 Intel QuickSync
if [ -d "/dev/dri" ]; then
    echo "✅ 检测到 Intel GPU (QuickSync 可能可用):"
    ls -la /dev/dri/ 2>/dev/null || true
    echo ""
    echo "推荐配置:"
    echo "  - 环境变量:"
    echo "      JELLYFIN_HW_DEVICE=intel-quicksync"
    echo "      JELLYFIN_HW_DEVICE_TYPE=vaapi"
    echo "      JELLYFIN_VAAPI_DEVICE=/dev/dri/renderD128"
    echo "  - 运行前提: 宿主机已加载 i915 内核模块"
    echo ""
fi

# 检测 AMD GPU (ROCm)
if lspci | grep -i "amd\|radeon" &> /dev/null; then
    echo "✅ 检测到 AMD GPU (ROCm 可能可用):"
    lspci | grep -i "amd\|radeon" | head -2
    echo ""
    echo "推荐配置:"
    echo "  - 环境变量:"
    echo "      JELLYFIN_HW_DEVICE=amf"
    echo "      JELLYFIN_HW_DEVICE_TYPE=amf"
    echo "  - 运行前提: 宿主机已安装 AMD GPU 驱动"
    echo ""
fi

# 如果没有检测到 GPU
if ! command -v nvidia-smi &> /dev/null && [ ! -d "/dev/dri" ] && ! lspci | grep -i "amd\|radeon" &> /dev/null; then
    echo "⚠️  未检测到可用的硬件加速设备"
    echo "推荐配置:"
    echo "  - 不设置任何 JELLYFIN_HW_DEVICE 变量 → 使用 CPU 软解"
    echo "  - 预期性能: 1080p 软解可能达到 2-3 倍速，4K 可能卡顿"
    echo ""
fi

echo "=== 检测完成 ==="
echo ""
echo "注意: 硬件加速需要满足以下条件:"
echo "1. 宿主机已安装对应 GPU 驱动"
echo "2. Docker 已配置 GPU 支持 (nvidia-container-toolkit 或 /dev/dri 映射)"
echo "3. 容器启动时传递正确的设备权限"