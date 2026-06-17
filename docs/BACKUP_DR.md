# Backup & Disaster Recovery (DR) Strategy for HomeLab Stack

## 1. Overview
This document defines the professional backup and recovery strategy for the HomeLab environment. The goal is to ensure zero data loss and minimum downtime (RTO/RPO) in case of hardware failure, accidental deletion, or system corruption.

## 2. Technical Stack
- **Backup Tool**: [Restic](https://restic.net/) (Chosen for deduplication, encryption, and cloud-native support).
- **Database Dumps**: `pg_dumpall` (PostgreSQL) and `mysqldump` (MySQL/MariaDB).
- **Schedules**: Systemd Timers / Cron.
- **Storage**: Local encrypted repository (default) with support for S3/SFTP/Azure.

## 3. Backup Architecture
The backup process follows a tiered approach:

### Tier 1: Configuration & Code
- **What**: All files in `/config` and `/stacks`.
- **Frequency**: Daily.
- **Method**: Restic snapshot of the project root.

### Tier 2: Persistent Database Data
- **What**: All databases (Postgres, MySQL).
- **Frequency**: Daily.
- **Method**: Logical dumps to temporary files, then captured by Restic.

### Tier 3: Docker Volumes
- **What**: Application data stored in named Docker volumes.
- **Frequency**: Daily.
- **Method**: Restic snapshot of volume mount points.

## 4. Backup Pipeline (`scripts/backup-manager.sh`)
The `backup-manager.sh` script automates the following workflow:
1. **Initialization**: Checks and initializes the Restic repository.
2. **Pre-backup**: Triggers database dumps to `/tmp/homelab_db_dumps`.
3. **Snapshot**: Creates a global Restic snapshot of the entire project directory.
4. **Maintenance**: 
   - `forget`: Removes snapshots based on the retention policy (e.g., keep last 7 daily).
   - `prune`: Deletes unreferenced data chunks from the repository.
5. **Validation**: Runs `restic check` to ensure no data corruption.

## 5. Disaster Recovery Plan (`scripts/restore-manager.sh`)
In the event of a total system loss, the recovery process is as follows:

### Step 1: Basic Environment Setup
1. Install Docker and Docker Compose.
2. Install Restic.
3. Clone the `homelab-stack` repository.

### Step 2: Data Restoration
Run the restore manager:
```bash
./scripts/restore-manager.sh restore
```
This will:
1. Restore the latest snapshot from the Restic repository to the project root.
2. Re-create the directory structure.

### Step 3: Infrastructure Deployment
The manager automatically deploys stacks in the correct dependency order:
`Base` $\rightarrow$ `Databases` $\rightarrow$ `Network` $\rightarrow$ `SSO` $\rightarrow$ `Monitoring` $\rightarrow$ `Others`.

### Step 4: Database Import
The manager identifies restored `.sql` dumps and imports them into the freshly started database containers.

## 6. Recovery Objectives
- **RPO (Recovery Point Objective)**: 24 hours (based on daily backup schedule).
- **RTO (Recovery Time Objective)**: ~15-30 minutes (automated restore and deploy).

## 7. Maintenance & Testing
It is recommended to perform a **Dry Run Restore** once a month to a separate test directory to verify that the backup chain is intact.
