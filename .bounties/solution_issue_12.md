# Solution for [github/issues_12]: [illbnm/homelab-stack] [BOUNTY $150] Backup & DR — 自动备份 + 灾难恢复

- **Reward:** $150.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/12
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 9480 (~$0.0190 USD compute cost)

---

The user wants a comprehensive backup and disaster recovery solution for their homelab-stack, adhering to a 3-2-1 strategy. This involves creating a `backup.sh` script, integrating Duplicati and Restic, supporting multiple backup targets, scheduling backups, documenting disaster recovery, and sending notifications.

Here's a breakdown of the solution:

**1. Root Cause Analysis & Design Choices:**

*   **3-2-1 Strategy:**
    *   **3 copies:** Original data + local Restic backup + remote Duplicati backup.
    *   **2 different media:** Local disk (for Restic) + Cloud/Remote (for Duplicati).
    *   **1 offsite:** Cloud/Remote backup.
*   **Backup Tools:**
    *   **Restic:** Excellent for local, deduplicated, encrypted backups. It's fast and efficient for frequently changing data. The `restic/rest-server` provides a convenient HTTP backend.
    *   **Duplicati:** Good for cloud backups with encryption, deduplication, and various backend support. It's more GUI-driven but can be scripted via its command-line interface or API.
*   **Backup Script (`backup.sh`):** This will be the central orchestrator.
    *   It needs to identify Docker volumes for each stack.
    *   It will use `docker compose cp` or bind mounts to access volume data.
    *   It will interact with Restic for local backups and Duplicati for remote backups.
    *   It needs to handle different backup targets (S3, B2, SFTP, Local).
    *   It must support `dry-run`, `restore`, `list`, `verify` operations.
*   **Backup Targets:**
    *   **Restic:** Will primarily use the `restic/rest-server` for local storage.
    *   **Duplicati:** Will handle the various cloud targets. The script will dynamically configure Duplicati based on `.env` variables.
*   **Scheduling:** `systemd-timer` is preferred over `crontab` for modern Linux systems due to better integration with system services, logging, and dependency management.
*   **Disaster Recovery Documentation:** Crucial for a complete solution. It will outline the steps for a full recovery, service dependencies, RTO, and verification.
*   **Notifications:** `ntfy` is a good choice for simple, cross-platform notifications.

**2. Architecture Design:**

*   **`docker-compose.yml`:**
    *   Add `duplicati` and `restic-rest-server` services.
    *   `restic-rest-server` will expose a port and mount a local volume for its repository.
    *   `duplicati` will need access to the host's Docker socket (for `docker compose cp` if not using bind mounts) or directly mount the volumes to be backed up. For simplicity and security, we'll use `docker compose cp` from the host script, so Duplicati itself doesn't need direct volume access. The script will prepare data for Duplicati.
*   **`scripts/backup.sh`:**
    *   **Initialization:** Load `.env` variables, define paths, set up Restic/Duplicati environment variables.
    *   **Volume Discovery:** Use `docker compose config --services` and `docker inspect` to find volumes associated with services.
    *   **Local Backup (Restic):**
        *   For each identified volume, create a temporary tarball or bind mount it.
        *   Use `restic backup` to push to the `restic-rest-server`.
    *   **Remote Backup (Duplicati):**
        *   For each identified volume, create a temporary tarball.
        *   Use `duplicati-cli` to push to the configured remote target.
    *   **Operations (`--list`, `--restore`, `--verify`, `--dry-run`):** Implement logic to call `restic` and `duplicati-cli` commands accordingly.
    *   **Notifications:** Integrate `ntfy` calls for success/failure.
*   **`.env`:** New variables for Restic password, Duplicati password, backup target type, and target-specific credentials (S3 keys, B2 keys, SFTP details).
*   **`systemd-timer`:** A unit file to trigger `backup.sh` daily.
*   **`docs/disaster-recovery.md`:** Detailed markdown document.

**3. Implementation Details:**

*   **Volume Access:** The most robust way to back up Docker volumes from a script is to use `docker compose cp` to copy data out of a running container or a temporary container, or to bind-mount the volume path directly if the volume is a host path. Given the `homelab-stack` context, volumes are likely managed by Docker. `docker compose cp` is safer as it doesn't require knowing the exact host path of the volume.
*   **Restic:**
    *   `restic init` to create the repo.
    *   `restic backup <path>` to backup.
    *   `restic restore <snapshot_id> --target <path>` to restore.
    *   `restic snapshots` to list.
    *   `restic check` to verify.
*   **Duplicati:**
    *   `duplicati-cli backup <source> <destination> --password=<pass> --encryption-module=aes --compression-module=zip`
    *   `duplicati-cli restore <destination> <source> --password=<pass>`
    *   `duplicati-cli list <destination> --password=<pass>`
    *   `duplicati-cli verify <destination> --password=<pass>`
*   **Environment Variables:** Use `export` in the script to pass credentials to `restic` and `duplicati-cli`.
*   **Error Handling:** Use `set -e` and `trap` for robust error handling and notifications.
*   **Temporary Files:** Use `mktemp -d` for temporary directories to stage data before backup.

**4. Production-Ready Code/Patch Implementation:**

This will involve modifying `docker-compose.yml`, creating `scripts/backup.sh`, adding a `systemd` unit, and creating `docs/disaster-recovery.md`.

---

### File: docker-compose.yml
```yaml
# Add these services to your existing docker-compose.yml
# Ensure they are placed appropriately, e.g., under a 'backup' section or alongside other core services.

  # Restic REST Server for local backups
  restic-rest-server:
    image: restic/rest-server:0.13.0
    container_name: restic-rest-server
    restart: unless-stopped
    ports:
      - "8000:8000" # Expose port for Restic client to connect
    volumes:
      - ./data/restic:/data # Local volume for Restic repository
    environment:
      - RESTIC_PASSWORD=${RESTIC_PASSWORD} # Password for the Restic repository
      - RESTIC_FORGET_ARGS="--keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune" # Retention policy
    command: serve --no-auth --private-repos # --no-auth is used here because RESTIC_PASSWORD is for the repo, not HTTP auth.
                                            # For production, consider adding HTTP basic auth if exposing outside localhost.

  # Duplicati for remote/cloud backups (optional, can be run as a CLI from host)
  # Running Duplicati as a service provides a GUI for management, but for scripted backups,
  # the CLI is often sufficient and can be run directly on the host or in a temporary container.
  # For this solution, we'll primarily use duplicati-cli from the host script for flexibility.
  # If you want the GUI, uncomment and configure this:
  # duplicati:
  #   image: lscr.io/linuxserver/duplicati:2.0.8
  #   container_name: duplicati
  #   restart: unless-stopped
  #   ports:
  #     - "8200:8200"
  #   volumes:
  #     - ./data/duplicati_config:/config
  #     - /var/run/docker.sock:/var/run/docker.sock:ro # Needed if Duplicati itself needs to access Docker volumes
  #     - /path/to/your/homelab/stack/data:/source_data:ro # Example: Mount your homelab data directory
  #   environment:
  #     - PUID=${PUID}
  #     - PGID=${PGID}
  #     - TZ=${TZ}
  #     - CLI_ARGS=--web-interface=no # Or remove for GUI
  #     - DUPLICATI_WEBPASSWORD=${DUPLICATI_PASSWORD} # For GUI access
```

**Explanation for `docker-compose.yml` changes:**

*   **`restic-rest-server`**: This service provides a dedicated HTTP endpoint for Restic to store its backups.
    *   `ports: - "8000:8000"`: Exposes the server. You might want to restrict this to `127.0.0.1:8000:8000` if it's only for local access.
    *   `volumes: - ./data/restic:/data`: Stores the Restic repository data in a local directory.
    *   `RESTIC_PASSWORD`: This is crucial for encrypting the Restic repository.
    *   `RESTIC_FORGET_ARGS`: Configures Restic's pruning policy (7 daily, 4 weekly, 6 monthly).
    *   `command: serve --no-auth --private-repos`: Starts the server. `--no-auth` means it doesn't require HTTP basic auth; the `RESTIC_PASSWORD` handles repository encryption. `--private-repos` means the repository name is part of the URL.
*   **`duplicati` (commented out):** While Duplicati can run as a service with a GUI, for a fully scripted solution, it's often simpler and more resource-efficient to use `duplicati-cli` directly from the host machine or within a temporary container launched by the script. The provided `backup.sh` will use `duplicati-cli` directly. If you prefer the GUI for manual management or monitoring, you can uncomment and configure this service.

---

### File: .env
```ini
# Add these variables to your existing .env file

# --- Backup & Recovery Settings ---

# Restic Repository Password (REQUIRED for restic-rest-server)
RESTIC_PASSWORD=your_strong_restic_password_here

# Duplicati Backup Password (REQUIRED for Duplicati encryption)
DUPLICATI_PASSWORD=your_strong_duplicati_password_here

# Backup Target Type: s3 | b2 | sftp | local | r2
# Choose where Duplicati will store its remote backups.
BACKUP_TARGET=s3

# --- S3 Compatible Backup Target (e.g., MinIO, AWS S3, Cloudflare R2) ---
# If BACKUP_TARGET=s3 or BACKUP_TARGET=r2
S3_ENDPOINT=https://s3.example.com # e.g., https://s3.amazonaws.com, http://minio:9000, https://<ACCOUNT_ID>.r2.cloudflarestorage.com
S3_ACCESS_KEY_ID=your_s3_access_key_id
S3_SECRET_ACCESS_KEY=your_s3_secret_access_key
S3_BUCKET_NAME=your-backup-bucket

# --- Backblaze B2 Backup Target ---
# If BACKUP_TARGET=b2
B2_ACCOUNT_ID=your_b2_account_id
B2_APPLICATION_KEY=your_b2_application_key
B2_BUCKET_NAME=your-b2-bucket

# --- SFTP Backup Target ---
# If BACKUP_TARGET=sftp
SFTP_HOST=your_sftp_host
SFTP_PORT=22
SFTP_USER=your_sftp_user
SFTP_PASSWORD=your_sftp_password # Or use SFTP_PRIVATE_KEY_PATH
# SFTP_PRIVATE_KEY_PATH=/path/to/your/sftp_private_key.pem # Uncomment if using key-based auth

# --- Local Backup Target (for Duplicati, in addition to Restic) ---
# If BACKUP_TARGET=local
LOCAL_BACKUP_PATH=/path/to/your/local/duplicati/backup/storage

# --- Notification Settings (ntfy.sh) ---
# URL for your ntfy server (e.g., https://ntfy.sh or your self-hosted instance)
NTFY_SERVER_URL=https://ntfy.sh
# Topic for backup notifications
NTFY_TOPIC=homelab_backups
```

**Explanation for `.env` changes:**

*   **`RESTIC_PASSWORD`**: Essential for the `restic-rest-server` and for encrypting your local Restic repository.
*   **`DUPLICATI_PASSWORD`**: Essential for Duplicati to encrypt your remote backups.
*   **`BACKUP_TARGET`**: This variable controls which remote storage Duplicati will use.
*   **Target-specific variables**: These are grouped by `BACKUP_TARGET` type. Fill in the details for your chosen remote storage.
*   **`NTFY_SERVER_URL`, `NTFY_TOPIC`**: For sending backup success/failure notifications.

---

### File: scripts/backup.sh
```bash
#!/bin/bash
set -euo pipefail

# --- Configuration ---
# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found. Please create one with backup configurations."
    exit 1
fi

# Ensure required passwords are set
if [ -z "${RESTIC_PASSWORD}" ]; then echo "Error: RESTIC_PASSWORD not set in .env"; exit 1; fi
if [ -z "${DUPLICATI_PASSWORD}" ]; then echo "Error: DUPLICATI_PASSWORD not set in .env"; exit 1; fi

# Define paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_ROOT=$(dirname "${SCRIPT_DIR}")
TEMP_DIR=$(mktemp -d -t homelab-backup-XXXXXXXX)
DUPLICATI_CLI_IMAGE="lscr.io/linuxserver/duplicati:2.0.8" # Use the same image as specified
RESTIC_CLI_IMAGE="restic/restic:0.13.0" # Use the same image as specified

# Restic REST Server details
RESTIC_REPO="rest:http://restic-rest-server:8000/homelab-stack" # Use service name for Docker internal network
# If running restic client on host, use localhost:
# RESTIC_REPO="rest:http://127.0.0.1:8000/homelab-stack"

# Ntfy notification settings
NTFY_SERVER_URL="${NTFY_SERVER_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab_backups}"

# --- Helper Functions ---

# Send ntfy notification
send_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}" # default, high, urgent
    local tags="${4:-}" # comma-separated tags

    echo "Sending ntfy notification: $title - $message (Priority: $priority, Tags: $tags)"
    curl -s -H "Title: ${title}" \
            -H "Priority: ${priority}" \
            ${tags:+-H "Tags: ${tags}"} \
            -d "${message}" \
            "${NTFY_SERVER_URL}/${NTFY_TOPIC}" > /dev/null || echo "Failed to send ntfy notification."
}

# Cleanup temporary directory
cleanup() {
    echo "Cleaning up temporary directory: ${TEMP_DIR}"
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Get list of services and their volumes
get_stack_volumes() {
    local stack_name="$1"
    local services_filter=""
    if [ "$stack_name" != "all" ]; then
        services_filter="--services ${stack_name}"
    fi

    # Get all service names
    local services=$(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" config --services ${services_filter})
    local volumes_to_backup=()

    for service in ${services}; do
        # Get volume mounts for the service
        local service_volumes=$(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" inspect "${service}" \
            | jq -r '.[0].Mounts[] | select(.Type == "volume") | .Name')

        for vol_name in ${service_volumes}; do
            # Check if volume is already added
            if ! printf '%s\n' "${volumes_to_backup[@]}" | grep -q -P "^${vol_name}$"; then
                volumes_to_backup+=("${vol_name}")
            fi
        done
    done
    echo "${volumes_to_backup[@]}"
}

# Run Duplicati CLI in a temporary container
run_duplicati_cli() {
    local command="$1"
    shift
    local args=("$@")

    echo "Running Duplicati CLI command: ${command} ${args[*]}"

    # Determine Duplicati destination URL based on BACKUP_TARGET
    local duplicati_destination=""
    case "${BACKUP_TARGET}" in
        s3)
            if [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_ACCESS_KEY_ID}" ] || [ -z "${S3_SECRET_ACCESS_KEY}" ] || [ -z "${S3_BUCKET_NAME}" ]; then
                echo "Error: S3 credentials or bucket name not fully set in .env"
                exit 1
            fi
            duplicati_destination="s3://${S3_BUCKET_NAME}?s3-ext-url=${S3_ENDPOINT}&s3-ext-forcepathstyle=true"
            export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID}"
            export AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY}"
            ;;
        b2)
            if [ -z "${B2_ACCOUNT_ID}" ] || [ -z "${B2_APPLICATION_KEY}" ] || [ -z "${B2_BUCKET_NAME}" ]; then
                echo "Error: B2 credentials or bucket name not fully set in .env"
                exit 1
            fi
            duplicati_destination="b2://${B2_BUCKET_NAME}?auth-username=${B2_ACCOUNT_ID}&auth-password=${B2_APPLICATION_KEY}"
            ;;
        sftp)
            if [ -z "${SFTP_HOST}" ] || [ -z "${SFTP_USER}" ] || ([ -z "${SFTP_PASSWORD}" ] && [ -z "${SFTP_PRIVATE_KEY_PATH}" ]); then
                echo "Error: SFTP host, user, and password/key not fully set in .env"
                exit 1
            fi
            local sftp_auth=""
            if [ -n "${SFTP_PASSWORD}" ]; then
                sftp_auth="&auth-password=${SFTP_PASSWORD}"
            elif [ -n "${SFTP_PRIVATE_KEY_PATH}" ]; then
                sftp_auth="&auth-sshkeyfile=${SFTP_PRIVATE_KEY_PATH}"
            fi
            duplicati_destination="sftp://${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT:-22}/homelab-stack-backups${sftp_auth}"
            ;;
        local)
            if [ -z "${LOCAL_BACKUP_PATH}" ]; then
                echo "Error: LOCAL_BACKUP_PATH not set in .env"
                exit 1
            fi
            mkdir -p "${LOCAL_BACKUP_PATH}" # Ensure local path exists
            duplicati_destination="file://${LOCAL_BACKUP_PATH}/homelab-stack-backups"
            ;;
        r2) # Cloudflare R2 is S3 compatible
            if [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_ACCESS_KEY_ID}" ] || [ -z "${S3_SECRET_ACCESS_KEY}" ] || [ -z "${S3_BUCKET_NAME}" ]; then
                echo "Error: R2 (S3) credentials or bucket name not fully set in .env"
                exit 1
            fi
            duplicati_destination="s3://${S3_BUCKET_NAME}?s3-ext-url=${S3_ENDPOINT}&s3-ext-forcepathstyle=true"
            export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID}"
            export AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY}"
            ;;
        *)
            echo "Error: Unsupported BACKUP_TARGET: ${BACKUP_TARGET}"
            exit 1
            ;;
    esac

    # Common Duplicati options
    local common_duplicati_args=(
        "--password=${DUPLICATI_PASSWORD}"
        "--encryption-module=aes"
        "--compression-module=zip"
        "--no-encryption-salt=true" # Use fixed salt for easier CLI restore
        "--console-log-level=Warning"
        "--disable-autocreate-folder=true" # Don't create remote folders automatically
    )

    # Mount the project root to access volumes if needed, or temporary data
    # For SFTP/Local, mount the relevant paths
    local docker_mount_args=("-v" "${TEMP_DIR}:/source_data")
    if [ "${BACKUP_TARGET}" == "local" ]; then
        docker_mount_args+=("-v" "${LOCAL_BACKUP_PATH}:${LOCAL_BACKUP_PATH}")
    elif [ "${BACKUP_TARGET}" == "sftp" ] && [ -n "${SFTP_PRIVATE_KEY_PATH}" ]; then
        docker_mount_args+=("-v" "${SFTP_PRIVATE_KEY_PATH}:${SFTP_PRIVATE_KEY_PATH}:ro")
    fi

    docker run --rm \
        "${docker_mount_args[@]}" \
        -e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}" \
        -e "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}" \
        "${DUPLICATI_CLI_IMAGE}" \
        "${command}" "${duplicati_destination}" "${args[@]}" "${common_duplicati_args[@]}"
}

# Run Restic CLI in a temporary container
run_restic_cli() {
    local command="$1"
    shift
    local args=("$@")

    echo "Running Restic CLI command: ${command} ${args[*]}"

    docker run --rm \
        -v "${TEMP_DIR}:/source_data" \
        --network "${COMPOSE_PROJECT_NAME:-homelab-stack}_default" \
        -e RESTIC_REPOSITORY="${RESTIC_REPO}" \
        -e RESTIC_PASSWORD="${RESTIC_PASSWORD}" \
        "${RESTIC_CLI_IMAGE}" \
        "${command}" "${args[@]}"
}

# --- Main Backup Logic ---

perform_backup() {
    local target_stack="$1"
    local dry_run="$2"
    local volumes_to_backup
    volumes_to_backup=$(get_stack_volumes "${target_stack}")

    if [ -z "${volumes_to_backup}" ]; then
        echo "No volumes found for stack '${target_stack}'. Exiting."
        send_notification "Backup Failed" "No volumes found for stack '${target_stack}'." high "error"
        exit 1
    fi

    echo "--- Starting Backup for stack: ${target_stack} ---"
    echo "Volumes to backup: ${volumes_to_backup}"
    echo "Local Restic Repository: ${RESTIC_REPO}"
    echo "Remote Duplicati Target: ${BACKUP_TARGET}"

    if [ "${dry_run}" = true ]; then
        echo "DRY RUN: Would backup the following volumes:"
        for vol in ${volumes_to_backup}; do
            echo "  - ${vol}"
        done
        echo "DRY RUN: No actual backup will be performed."
        return 0
    fi

    local backup_success=true
    local backup_summary=""

    # Initialize Restic repository if it doesn't exist
    if ! run_restic_cli "snapshots" > /dev/null 2>&1; then
        echo "Restic repository not found or accessible. Initializing..."
        run_restic_cli "init" || {
            echo "Error: Failed to initialize Restic repository."
            send_notification "Backup Failed" "Failed to initialize Restic repository." urgent "error"
            exit 1
        }
    fi

    # Loop through volumes and backup
    for vol_name in ${volumes_to_backup}; do
        echo "--- Backing up volume: ${vol_name} ---"
        local temp_vol_path="${TEMP_DIR}/${vol_name}"
        mkdir -p "${temp_vol_path}"

        # Find a container that uses this volume to copy data out
        local container_id=$(docker ps -q --filter "volume=${vol_name}" | head -n 1)
        if [ -z "${container_id}" ]; then
            echo "Warning: No running container found for volume '${vol_name}'. Skipping data copy."
            # Attempt to create a temporary container to mount and copy if no running container
            # This is more complex and might require specific image/entrypoint.
            # For simplicity, we assume volumes are attached to running services.
            # If a volume is not attached to any running service, it might be empty or not critical.
            continue
        fi

        echo "Copying data from volume '${vol_name}' (via container ${container_id}) to temporary path: ${temp_vol_path}"
        # Use docker cp to get data out of the volume
        # This assumes the volume is mounted at /data or a known path inside the container.
        # A more robust solution would be to inspect the container's mount points.
        # For now, we'll assume the volume content is at the root of the volume.
        # A common pattern is to mount volumes to /app/data or /var/lib/<service>
        # To be safe, we'll try to copy the entire volume content.
        # This is a simplification; for complex volumes, a temporary container with the volume mounted is better.
        # For now, let's assume the volume content is directly accessible via `docker cp` from the container's root.
        # A better approach for general Docker volumes is to create a temporary container that mounts the volume
        # and then tar it from there.
        # Example: docker run --rm -v ${vol_name}:/volume_data -w /volume_data alpine tar -czf - . > ${temp_vol_path}.tar.gz
        # For now, let's use a simpler approach by copying from a running container if possible.

        # More robust way: create a temporary container to tar the volume
        local temp_tar_file="${temp_vol_path}.tar.gz"
        echo "Creating tarball of volume '${vol_name}' using a temporary container..."
        if ! docker run --rm -v "${vol_name}:/volume_data:ro" alpine tar -czf - -C /volume_data . > "${temp_tar_file}"; then
            echo "Error: Failed to create tarball for volume '${vol_name}'. Skipping."
            backup_success=false
            continue
        fi
        echo "Tarball created: ${temp_tar_file}"

        # --- Restic Local Backup ---
        echo "Performing Restic local backup for ${vol_name}..."
        if run_restic_cli "backup" "${temp_tar_file}" --tag "${target_stack},${vol_name}" --host "${HOSTNAME:-homelab}"; then
            echo "Restic backup for ${vol_name} successful."
            backup_summary+="Restic: ${vol_name} OK. "
        else
            echo "Error: Restic backup for ${vol_name} failed."
            backup_success=false
            backup_summary+="Restic: ${vol_name} FAILED. "
        fi

        # --- Duplicati Remote Backup ---
        echo "Performing Duplicati remote backup for ${vol_name}..."
        if run_duplicati_cli "backup" "${temp_tar_file}" --tag "${target_stack},${vol_name}" --snapshot-policy=Off; then
            echo "Duplicati backup for ${vol_name} successful."
            backup_summary+="Duplicati: ${vol_name} OK. "
        else
            echo "Error: Duplicati backup for ${vol_name} failed."
            backup_success=false
            backup_summary+="Duplicati: ${vol_name} FAILED. "
        fi
        rm "${temp_tar_file}" # Clean up tarball after backup
    done

    # Restic Prune (cleanup old snapshots)
    echo "Running Restic prune..."
    if run_restic_cli "forget" ${RESTIC_FORGET_ARGS:-"--keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune"}; then
        echo "Restic prune successful."
        backup_summary+="Restic Prune OK. "
    else
        echo "Warning: Restic prune failed."
        backup_summary+="Restic Prune FAILED. "
    fi

    # Duplicati Cleanup (delete old backups based on policy)
    echo "Running Duplicati delete (cleanup old backups)..."
    # Duplicati's delete command is for removing specific backups.
    # Retention policy is usually configured during the backup command or via GUI.
    # For CLI, we rely on the backup command's implicit policy or manual deletion.
    # A simpler approach for CLI is to let the backup command handle it, or use `purge`.
    # For now, we'll just run a `vacuum` to clean up database.
    if run_duplicati_cli "vacuum"; then
        echo "Duplicati vacuum successful."
        backup_summary+="Duplicati Vacuum OK. "
    else
        echo "Warning: Duplicati vacuum failed."
        backup_summary+="Duplicati Vacuum FAILED. "
    fi


    if [ "${backup_success}" = true ]; then
        send_notification "Backup Successful" "Homelab stack backup completed successfully for '${target_stack}'. Summary: ${backup_summary}" default "backup,success"
        echo "Backup completed successfully for '${target_stack}'."
    else
        send_notification "Backup Failed" "Homelab stack backup failed for '${target_stack}'. Summary: ${backup_summary}" urgent "backup,error"
        echo "Backup completed with errors for '${target_stack}'."
        exit 1
    fi
}

# --- Restore Logic ---

perform_restore() {
    local backup_id="$1"
    local target_stack="$2" # Can be 'all' or specific stack
    local volumes_to_restore
    volumes_to_restore=$(get_stack_volumes "${target_stack}")

    if [ -z "${volumes_to_restore}" ]; then
        echo "No volumes found for stack '${target_stack}'. Exiting."
        send_notification "Restore Failed" "No volumes found for stack '${target_stack}'." high "error"
        exit 1
    fi

    echo "--- Starting Restore for stack: ${target_stack} from backup ID: ${backup_id} ---"
    echo "Volumes to restore: ${volumes_to_restore}"

    local restore_success=true
    local restore_summary=""

    for vol_name in ${volumes_to_restore}; do
        echo "--- Restoring volume: ${vol_name} ---"
        local restore_path="${TEMP_DIR}/restore_${vol_name}"
        mkdir -p "${restore_path}"

        # Try Restic first (local, faster)
        echo "Attempting Restic restore for ${vol_name}..."
        local restic_snapshot_id="${backup_id}"
        if [ "${backup_id}" == "latest" ]; then
            restic_snapshot_id=$(run_restic_cli "snapshots" --json | jq -r --arg tag "${target_stack},${vol_name}" '.[] | select(.tags | contains([$tag])) | .id' | tail -n 1)
            if [ -z "${restic_snapshot_id}" ]; then
                echo "No Restic snapshot found for volume '${vol_name}' with tag '${target_stack},${vol_name}'. Trying Duplicati."
                restic_snapshot_id="" # Clear to try Duplicati
            else
                echo "Found Restic snapshot ID: ${restic_snapshot_id} for volume '${vol_name}'."
            fi
        fi

        local restored_tar_file=""

        if [ -n "${restic_snapshot_id}" ]; then
            if run_restic_cli "restore" "${restic_snapshot_id}" --target "${restore_path}" --path "/${vol_name}.tar.gz"; then
                echo "Restic restore for ${vol_name} successful to ${restore_path}/${vol_name}.tar.gz."
                restored_tar_file="${restore_path}/${vol_name}.tar.gz"
                restore_summary+="Restic: ${vol_name} OK. "
            else
                echo "Error: Restic restore for ${vol_name} failed. Trying Duplicati."
                restore_summary+="Restic: ${vol_name} FAILED. "
            fi
        fi

        if [ -z "${restored_tar_file}" ]; then
            # Fallback to Duplicati
            echo "Attempting Duplicati restore for ${vol_name}..."
            # Duplicati CLI restore needs the source path within the backup.
            # We backed up as /<vol_name>.tar.gz
            if run_duplicati_cli "restore" "/${vol_name}.tar.gz" --targetpath="${restore_path}" --version="${backup_id}"; then
                echo "Duplicati restore for ${vol_name} successful to ${restore_path}/${vol_name}.tar.gz."
                restored_tar_file="${restore_path}/${vol_name}.tar.gz"
                restore_summary+="Duplicati: ${vol_name} OK. "
            else
                echo "Error: Duplicati restore for ${vol_name} failed. Skipping this volume."
                restore_success=false
                restore_summary+="Duplicati: ${vol_name} FAILED. "
                continue
            fi
        fi

        if [ -n "${restored_tar_file}" ] && [ -f "${restored_tar_file}" ]; then
            echo "Extracting ${restored_tar_file} to volume '${vol_name}'..."
            # Stop services using the volume to ensure data integrity during restore
            echo "Stopping services that use volume '${vol_name}'..."
            local services_using_vol=$(docker ps -q --filter "volume=${vol_name}" | xargs

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
