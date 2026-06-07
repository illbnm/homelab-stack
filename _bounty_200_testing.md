---
// FILE: .github/ISSUE_TEMPLATE/bounty-servers.md
---
name: 💰 Bounty - Servers Stack
about: 实现服务器层 (Docker, Kubernetes, Grafana, InfluxDB)
title: '[BOUNTY $150] Servers Stack — 服务器'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$150 USDT**

## 任务描述

实现完整的服务器层，包括 Docker 和 Kubernetes 管理，支持 Grafana 和 InfluxDB 数据可视化。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Docker | `docker:20.0.0` | 环境配置 |
| Kubernetes | `kubernetes:1.23.0` | 自动扩展 | 
| Grafana | `grafana/grafana:10.2.1` | 数据可视化 | 
| InfluxDB | `influxdb/influxdb:1.11.0` | 数据存储 | 

## 核心要求

### 1. 环境配置

- 使用 `docker-compose` 创建容器
- 通过 `kubectl` 或 `kubeadm` 管理集群
- 使用 `influxdb` 提供数据存储

### 2. 网络隔离

- 服务器容器