#!/bin/bash

# Database backup script with compression and retention
# Supports PostgreSQL, Redis, and MariaDB

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/backups"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/var/log/backup-databases.log"

# Database configurations
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PGPASSWORD="${PGPASSWORD:-}"

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

MARIADB_HOST="${MARIADB_HOST:-localhost}"
MARIADB_PORT="${MARIADB_PORT:-3306}"
MARIADB_USER="${MARIADB_USER:-root}"
MARIADB_PASSWORD="${MARIADB_PASSWORD:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup directories
create_backup_dirs() {
    mkdir -p "$BACKUP_DIR/postgresql"
    mkdir -p "$BACKUP_DIR/redis"
    mkdir -p "$BACKUP_DIR/mariadb"
}

# PostgreSQL backup
backup_postgresql() {
    log "Starting PostgreSQL backup..."
    
    local backup_file="$BACKUP_DIR/postgresql/postgresql_${TIMESTAMP}.sql"
    
    export PGPASSWORD
    
    if pg_dumpall -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -v > "$backup_file"; then
        # Compress the backup
        gzip "$backup_file"
        log "PostgreSQL backup completed: ${backup_file}.gz"
    else
        log "ERROR: PostgreSQL backup failed"
        return 1
    fi
}

# Redis backup
backup_redis() {
    log "Starting Redis backup..."
    
    local backup_file="$BACKUP_DIR/redis/redis_${TIMESTAMP}.rdb"
    
    # Trigger Redis save
    if [ -n "$REDIS_PASSWORD" ]; then
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" BGSAVE
    else
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" BGSAVE
    fi
    
    # Wait for background save to complete
    local save_in_progress=1
    while [ $save_in_progress -eq 1 ]; do
        if [ -n "$REDIS_PASSWORD" ]; then
            save_in_progress=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" LASTSAVE | xargs -I {} redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" EVAL "return redis.call('LASTSAVE') == tonumber(ARGV[1])" 0 {})
        else
            save_in_progress=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" LASTSAVE | xargs -I {} redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" EVAL "return redis.call('LASTSAVE') == tonumber(ARGV[1])" 0 {})
        fi
        sleep 1
    done
    
    # Copy RDB file
    local redis_data_dir="/var/lib/redis"
    if [ -f "$redis_data_dir/dump.rdb" ]; then
        cp "$redis_data_dir/dump.rdb" "$backup_file"
        gzip "$backup_file"
        log "Redis backup completed: ${backup_file}.gz"
    else
        log "ERROR: Redis dump.rdb file not found"
        return 1
    fi
}

# MariaDB backup
backup_mariadb() {
    log "Starting MariaDB backup..."
    
    local backup_file="$BACKUP_DIR/mariadb/mariadb_${TIMESTAMP}.sql"
    
    local mysql_opts="-h $MARIADB_HOST -P $MARIADB_PORT -u $MARIADB_USER"
    if [ -n "$MARIADB_PASSWORD" ]; then
        mysql_opts="$mysql_opts -p$MARIADB_PASSWORD"
    fi
    
    if mysqldump $mysql_opts --all-databases --single-transaction --routines --triggers > "$backup_file"; then
        # Compress the backup
        gzip "$backup_file"
        log "MariaDB backup completed: ${backup_file}.gz"
    else
        log "ERROR: MariaDB backup failed"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    find "$BACKUP_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    log "Cleanup completed"
}

# Check if databases are running
check_database_availability() {
    # Check PostgreSQL
    if ! pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" >/dev/null 2>&1; then
        log "WARNING: PostgreSQL is not available"
        return 1
    fi
    
    # Check Redis
    if ! timeout 5 bash -c "echo > /dev/tcp/$REDIS_HOST/$REDIS_PORT" >/dev/null 2>&1; then
        log "WARNING: Redis is not available"
        return 1
    fi
    
    # Check MariaDB
    if ! timeout 5 bash -c "echo > /dev/tcp/$MARIADB_HOST/$MARIADB_PORT" >/dev/null 2>&1; then
        log "WARNING: MariaDB is not available"
        return 1
    fi
    
    return 0
}

# Main backup function
main() {
    log "Starting database backup process..."
    
    # Create backup directories
    create_backup_dirs
    
    # Check database availability
    if ! check_database_availability; then
        log "Some databases are not available. Continuing with available ones..."
    fi
    
    local backup_errors=0
    
    # Perform backups
    if pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" >/dev/null 2>&1; then
        backup_postgresql || ((backup_errors++))
    fi
    
    if timeout 5 bash -c "echo > /dev/tcp/$REDIS_HOST/$REDIS_PORT" >/dev/null 2>&1; then
        backup_redis || ((backup_errors++))
    fi
    
    if timeout 5 bash -c "echo > /dev/tcp/$MARIADB_HOST/$MARIADB_PORT" >/dev/null 2>&1; then
        backup_mariadb || ((backup_errors++))
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    if [ $backup_errors -eq 0 ]; then
        log "All database backups completed successfully"
        exit 0
    else
        log "Database backup completed with $backup_errors errors"
        exit 1
    fi
}

# Run main function
main "$@"