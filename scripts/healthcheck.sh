#!/bin/sh
# healthcheck.sh — Check all containers are running + backup freshness
set -e

for container in duplicati restic; do
  STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "missing")
  if [ "$STATUS" != "running" ]; then
    echo "CRITICAL: Container $container is $STATUS"
  else
    echo "OK: $container is running"
  fi
done

# Check backup freshness (last restic snapshot)
LAST_SNAPSHOT=$(docker exec restic restic snapshots --json 2>/dev/null | grep -o '"time":"[^"]*"' | tail -1 | cut -d'"' -f4)
if [ -n "$LAST_SNAPSHOT" ]; then
  LAST_TS=$(date -d "$LAST_SNAPSHOT" +%s 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$(( (NOW - LAST_TS) / 3600 ))
  if [ "$AGE" -gt 48 ]; then
    echo "WARNING: Last backup was ${AGE}h ago (>48h threshold)"
  else
    echo "OK: Last backup ${AGE}h ago"
  fi
fi
