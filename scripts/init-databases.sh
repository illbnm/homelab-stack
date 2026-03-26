#!/bin/bash
set -e

# --- VALIDACIÓN DE SEGURIDAD ---
# Verificamos que las variables críticas existan para no crear DBs con pass vacíos
REQUIRED_VARS=(
    "NEXTCLOUD_DB_PASSWORD" 
    "GITEA_DB_PASSWORD" 
    "OUTLINE_DB_PASSWORD" 
    "AUTHENTIK_DB_PASSWORD" 
    "GRAFANA_DB_PASSWORD"
)

for VAR in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!VAR}" ]]; then
        echo "❌ ERROR: Variable $VAR is not set. Aborting initialization."
        exit 1
    fi
done

# --- FUNCIÓN DE CREACIÓN IDEMPOTENTE ---
create_db() {
    local db=$1
    local pass=$2
    
    # Definimos el usuario y DB root con valores por defecto seguros
    local pg_user="${POSTGRES_USER:-postgres}"
    local pg_db="${POSTGRES_DB:-postgres}"

    echo "🔍 Checking/Creating database and user for: $db..."

    # 1. Crear el Rol/Usuario si no existe
    psql -v ON_ERROR_STOP=1 --username "$pg_user" --dbname "$pg_db" <<-EOSQL
        DO \$$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$db') THEN
                CREATE ROLE $db WITH LOGIN PASSWORD '$pass';
            END IF;
        END
        \$$;
EOSQL

    # 2. Crear la Base de Datos si no existe y asignar privilegios
    # Nota: Usamos \gexec para ejecutar el string generado dinámicamente
    psql -v ON_ERROR_STOP=1 --username "$pg_user" --dbname "$pg_db" <<-EOSQL
        SELECT 'CREATE DATABASE $db'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
        GRANT ALL PRIVILEGES ON DATABASE $db TO $db;
EOSQL
}

# --- EJECUCIÓN ---
echo "🚀 Starting Database Initialization..."
sleep 3 # Espera de cortesía para el motor de PostgreSQL

create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea"     "${GITEA_DB_PASSWORD}"
create_db "outline"   "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana"   "${GRAFANA_DB_PASSWORD}"

echo "✅ All databases and users are ready and secured."

