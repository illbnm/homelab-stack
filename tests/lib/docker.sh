#!/usr/bin/env bash

docker_get_ip() {
  local cname="$1"
  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cname" 2>/dev/null || echo ""
}

docker_get_port() {
  local cname="$1"
  local port="$2"
  docker port "$cname" "$port" 2>/dev/null | head -n1 | awk -F: '{print $NF}' || echo ""
}

docker_check_network() {
  local net="$1"
  docker network inspect "$net" >/dev/null 2>&1
}
