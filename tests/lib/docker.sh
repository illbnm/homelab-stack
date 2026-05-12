# docker.sh — Docker utility functions for HomeLab tests

compose_up() { local f="$1"; docker compose -f "$f" up -d 2>&1; }
compose_down() { local f="$1"; docker compose -f "$f" down -t 10 2>&1; }
compose_config() { local f="$1"; docker compose -f "$f" config --quiet 2>&1; }
get_container_ip() { docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null; }
get_container_port() { docker inspect -f "{{(index (index .NetworkSettings.Ports \"$2\") 0).HostPort}}" "$1" 2>/dev/null; }
wait_for_port() { local p="$1" t="${2:-30}"; for i in $(seq 1 $t); do curl -s -o /dev/null "http://localhost:$p" && return 0; sleep 1; done; return 1; }
list_containers() { docker ps --format '{{.Names}}' | sort; }
list_stacks() { find stacks -maxdepth 2 -name 'docker-compose.yml' -exec dirname {} \; | xargs -n1 basename | sort; }
