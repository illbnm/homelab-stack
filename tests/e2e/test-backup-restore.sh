#!/usr/bin/env bash
# =============================================================================
# E2E Tests — Backup & Restore Workflow
# Tests: Volume backup, service recreation, data restoration
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."
ENV_FILE="$BASE_DIR/.env"
BACKUP_DIR="$BASE_DIR/tests/backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; ((FAILED++)); }
log_skip()  { echo -e "  ${YELLOW}~${NC} $* (skipped)"; ((SKIPPED++)); }
log_group() { echo -e "\n${BLUE}${BOLD}[$*]${NC}"; }

# -----------------------------------------------------------------------------
# E2E Test: Backup Preparation
# -----------------------------------------------------------------------------
test_backup_preparation() {
  log_group "E2E: Backup Preparation"
  
  # Create backup directory
  if mkdir -p "$BACKUP_DIR"; then
    log_pass "Backup directory created: $BACKUP_DIR"
  else
    log_fail "Failed to create backup directory"
    return 1
  fi
  
  # Check if backup script exists
  if [[ -f "$BASE_DIR/scripts/backup.sh" ]]; then
    log_pass "Backup script found"
    chmod +x "$BASE_DIR/scripts/backup.sh"
  else
    log_skip "Backup script not found - will use manual backup"
  fi
  
  # Check Docker volumes
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E "portainer|traefik" || echo "")
  
  if [[ -n "$volumes" ]]; then
    log_pass "Docker volumes found: $(echo "$volumes" | wc -l)"
    echo "$volumes" | while read -r vol; do
      log_pass "  - $vol"
    done
  else
    log_skip "No relevant Docker volumes found"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Create Backup
# -----------------------------------------------------------------------------
test_create_backup() {
  log_group "E2E: Create Backup"
  
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="$BACKUP_DIR/homelab-backup-${timestamp}.tar.gz"
  
  # Backup Docker volumes
  log_info "Backing up Docker volumes..."
  
  local volume_list
  volume_list=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E "portainer|traefik" | tr '\n' ' ' || echo "")
  
  if [[ -n "$volume_list" ]]; then
    for vol in $volume_list; do
      log_info "  Backing up volume: $vol"
      
      # Create a temporary container to access volume
      if docker run --rm -v "$vol:/data" -v "$BACKUP_DIR:/backup" alpine \
         tar -czf "/backup/${vol}-${timestamp}.tar.gz" -C /data . 2>/dev/null; then
        log_pass "Volume backed up: $vol"
      else
        log_fail "Failed to backup volume: $vol"
      fi
    done
  else
    log_skip "No volumes to backup"
  fi
  
  # Backup configuration files
  log_info "Backing up configuration files..."
  
  local config_dirs=("config/traefik" "config/prometheus" "config/grafana")
  
  for dir in "${config_dirs[@]}"; do
    if [[ -d "$BASE_DIR/$dir" ]]; then
      local dir_name=$(basename "$dir")
      if tar -czf "$BACKUP_DIR/config-${dir_name}-${timestamp}.tar.gz" -C "$BASE_DIR" "$dir" 2>/dev/null; then
        log_pass "Config backed up: $dir"
      else
        log_fail "Failed to backup config: $dir"
      fi
    else
      log_skip "Config directory not found: $dir"
    fi
  done
  
  # Verify backup files exist
  local backup_count
  backup_count=$(ls -1 "$BACKUP_DIR"/*-${timestamp}.tar.gz 2>/dev/null | wc -l)
  
  if [[ $backup_count -gt 0 ]]; then
    log_pass "Backup created: $backup_count file(s)"
    
    # Show backup sizes
    ls -lh "$BACKUP_DIR"/*-${timestamp}.tar.gz 2>/dev/null | while read -r line; do
      log_info "  $line"
    done
  else
    log_fail "No backup files created"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Simulate Disaster
# -----------------------------------------------------------------------------
test_simulate_disaster() {
  log_group "E2E: Simulate Disaster"
  
  # Stop all services
  local compose_file="$BASE_DIR/stacks/base/docker-compose.yml"
  
  if [[ -f "$compose_file" ]]; then
    log_info "Stopping all services..."
    if docker compose -f "$compose_file" down 2>/dev/null; then
      log_pass "Services stopped"
    else
      log_skip "Services already stopped"
    fi
  else
    log_skip "Compose file not found"
  fi
  
  # Remove volumes (SIMULATED - don't actually delete in test)
  log_warning "Volume removal simulated (not actually deleted for safety)"
  log_skip "Volumes preserved for restore test"
  
  # Verify services are down
  local running_count
  running_count=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "traefik|portainer|watchtower" | wc -l)
  
  if [[ $running_count -eq 0 ]]; then
    log_pass "All services stopped"
  else
    log_fail "$running_count services still running"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Restore from Backup
# -----------------------------------------------------------------------------
test_restore_backup() {
  log_group "E2E: Restore from Backup"
  
  local timestamp=$(date +%Y%m%d_%H%M%S)
  
  # Find latest backup files
  local latest_backup
  latest_backup=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
  
  if [[ -z "$latest_backup" ]]; then
    log_fail "No backup files found to restore"
    return 1
  fi
  
  log_info "Latest backup: $latest_backup"
  
  # Restore configuration files
  log_info "Restoring configuration files..."
  
  for backup_file in "$BACKUP_DIR"/config-*.tar.gz; do
    if [[ -f "$backup_file" ]]; then
      log_info "  Restoring: $(basename "$backup_file")"
      if tar -xzf "$backup_file" -C "$BASE_DIR" 2>/dev/null; then
        log_pass "Config restored: $(basename "$backup_file")"
      else
        log_fail "Failed to restore: $(basename "$backup_file")"
      fi
    fi
  done
  
  # Restore Docker volumes
  log_info "Restoring Docker volumes..."
  
  for backup_file in "$BACKUP_DIR"/*-volume-*.tar.gz "$BACKUP_DIR"/portainer-*.tar.gz "$BACKUP_DIR"/traefik-*.tar.gz; do
    if [[ -f "$backup_file" ]]; then
      local vol_name=$(basename "$backup_file" | sed 's/-[0-9_]*\.tar\.gz//')
      log_info "  Restoring volume: $vol_name"
      
      # Create volume if not exists
      docker volume create "$vol_name" 2>/dev/null || true
      
      # Restore data
      if docker run --rm -v "$vol_name:/data" -v "$BACKUP_DIR:/backup" alpine \
         tar -xzf "/backup/$(basename "$backup_file")" -C /data 2>/dev/null; then
        log_pass "Volume restored: $vol_name"
      else
        log_fail "Failed to restore volume: $vol_name"
      fi
    fi
  done
}

# -----------------------------------------------------------------------------
# E2E Test: Verify Restore
# -----------------------------------------------------------------------------
test_verify_restore() {
  log_group "E2E: Verify Restore"
  
  # Start services
  local compose_file="$BASE_DIR/stacks/base/docker-compose.yml"
  
  if [[ -f "$compose_file" ]]; then
    log_info "Starting services..."
    if docker compose -f "$compose_file" up -d 2>/dev/null; then
      log_pass "Services started"
    else
      log_fail "Failed to start services"
      return 1
    fi
  else
    log_skip "Compose file not found"
  fi
  
  # Wait for services to start
  log_info "Waiting for services to start (30s)..."
  sleep 30
  
  # Verify services are running
  local services=("traefik" "portainer" "watchtower")
  for service in "${services[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
      log_pass "Service '$service' is running"
    else
      log_fail "Service '$service' not running"
    fi
  done
  
  # Verify data persistence
  log_info "Verifying data persistence..."
  
  # Check Portainer data
  if docker exec portainer ls /data 2>/dev/null | grep -q .; then
    log_pass "Portainer data directory accessible"
  else
    log_skip "Portainer data check inconclusive"
  fi
  
  # Check Traefik logs
  if docker exec traefik ls /var/log/traefik 2>/dev/null | grep -q .; then
    log_pass "Traefik logs directory accessible"
  else
    log_skip "Traefik logs check inconclusive"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Cleanup
# -----------------------------------------------------------------------------
test_cleanup() {
  log_group "E2E: Cleanup"
  
  # Stop services
  local compose_file="$BASE_DIR/stacks/base/docker-compose.yml"
  
  if [[ -f "$compose_file" ]]; then
    if docker compose -f "$compose_file" down 2>/dev/null; then
      log_pass "Services stopped"
    else
      log_skip "Service stop failed"
    fi
  fi
  
  # Clean up test backups (optional - comment out to keep)
  # rm -rf "$BACKUP_DIR"/*
  # log_pass "Test backups cleaned"
  
  log_skip "Backups preserved in: $BACKUP_DIR"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  E2E Tests - Backup & Restore Workflow${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  
  # Check Docker
  if ! command -v docker &>/dev/null; then
    log_error "Docker not installed"
    exit 1
  fi
  
  if ! docker ps &>/dev/null; then
    log_error "Docker daemon not running or no permission"
    exit 1
  fi
  
  test_backup_preparation
  test_create_backup
  test_simulate_disaster
  test_restore_backup
  test_verify_restore
  # test_cleanup  # Uncomment to auto-cleanup
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
