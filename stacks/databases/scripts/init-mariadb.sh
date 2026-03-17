#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — MariaDB Multi-Tenant Initialization Script
# =============================================================================
# Mounted into the MariaDB container at:
#   /docker-entrypoint-initdb.d/10-init-mariadb.sh
#
# Creates isolated databases and users for services that need MySQL compat.
# Each service gets a dedicated user (<service>_user) with access only to
# its own database — following the principle of least privilege.
#
# IDEMPOTENT — safe to run multiple times.
# =============================================================================
set -euo pipefail

log_info()  { echo "[INIT-MARIADB][INFO]  $*"; }
log_warn()  { echo "[INIT-MARIADB][WARN]  $*"; }

# ---------------------------------------------------------------------------
# create_mariadb — Idempotent function to create a MariaDB database and user
# Usage: create_mariadb <db_name> <db_password>
# Creates: database "<db_name>" with user "<db_name>_user"
# ---------------------------------------------------------------------------
create_mariadb() {
  local db_name="$1"
  local db_password="$2"
  local db_user="${db_name}_user"

  if [ -z "${db_name}" ] || [ -z "${db_password}" ]; then
    echo "[INIT-MARIADB][ERROR] create_mariadb requires <db_name> and <db_password>" >&2
    return 1
  fi

  log_info "Setting up MariaDB database '${db_name}' with user '${db_user}'..."

  mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
    -- Create database (idempotent)
    CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    -- Create user (idempotent)
    CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}';

    -- Grant only necessary privileges on this specific database
    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES
      ON \`${db_name}\`.* TO '${db_user}'@'%';

    FLUSH PRIVILEGES;
EOSQL

  log_info "MariaDB database '${db_name}' setup complete. User '${db_user}' has scoped access only."
}

# =============================================================================
# Main — Create MariaDB databases
# =============================================================================
log_info "========================================"
log_info "Starting MariaDB initialization"
log_info "========================================"

# Nextcloud MariaDB (optional — can use PostgreSQL or MariaDB)
create_mariadb "nextcloud" "${NEXTCLOUD_MARIADB_PASSWORD:-nextcloud}"

log_info "========================================"
log_info "MariaDB initialization complete!"
log_info "Users: nextcloud_user (scoped to nextcloud DB only)"
log_info "========================================"
