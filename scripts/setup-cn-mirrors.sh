#!/bin/bash
set -e

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
  echo "此脚本必须以 root 用户身份运行"
  exit 1
fi

# 交互式询问是否在中国大陆
echo "================================================"
echo "Docker 镜像加速配置"
echo "================================================"
read -p "你是否在中国大陆网络环境？(y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "跳过镜像加速配置"
  exit 0
fi

# 创建 daemon.json 备份
DAEMON_JSON="/etc/docker/daemon.json"
if [[ -f "$DAEMON_JSON" ]]; then
  cp "$DAEMON_JSON" "$DAEMON_JSON.backup"
  echo "已备份原配置到 $DAEMON_JSON.backup"
fi

# 创建新的 daemon.json 配置
mkdir -p /etc/docker

cat > "$DAEMON_JSON" << 'EOF'
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "已写入 Docker 镜像加速配置"

# 重启 Docker daemon
echo "重启 Docker daemon..."
systemctl daemon-reload
systemctl restart docker

# 等待 Docker 启动
sleep 2

# 验证配置
echo "验证镜像加速配置..."
if docker pull hello-world > /dev/null 2>&1; then
  echo "✓ Docker 镜像加速验证成功"
  docker rmi hello-world > /dev/null 2>&1
else
  echo "✗ Docker 镜像加速验证失败"
  echo "已还原原配置"
  if [[ -f "$DAEMON_JSON.backup" ]]; then
    mv "$DAEMON_JSON.backup" "$DAEMON_JSON"
    systemctl daemon-reload
    systemctl restart docker
  fi
  exit 1
fi

echo "================================================"
echo "镜像加速配置完成"
echo "================================================"
