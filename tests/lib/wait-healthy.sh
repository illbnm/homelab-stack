#!/usr/bin/env bash
TIMEOUT=120
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --timeout) TIMEOUT="$2"; shift ;;
  esac
  shift
done
echo "Waiting for all containers to be healthy (timeout: ${TIMEOUT}s)..."
start=$(date +%s)
while true; do
  unhealthy=$(docker ps -q | xargs -r docker inspect -f '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' | grep -v ' healthy$' | grep -v ' none$' || true)
  if [ -z "$unhealthy" ]; then
    echo "All containers are healthy!"
    exit 0
  fi
  now=$(date +%s)
  if [ $((now - start)) -ge $TIMEOUT ]; then
    echo "Timeout reached. Unhealthy containers:"
    echo "$unhealthy"
    exit 1
  fi
  sleep 2
done
