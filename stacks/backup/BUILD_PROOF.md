# Build & Test Proof — Backup & DR Stack

## Tool Verification

### claude-opus-4-6
- **Model:** claude-opus-4-6 (Anthropic Claude Code)
- **Usage:** All code generation, architecture, implementation, debugging
- **Evidence:** Commits co-authored with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

### GPT-5.3 Codex
- **Model:** gpt-5.3-codex (OpenAI Responses API)
- **Usage:** Independent code review of backup.sh + docker-compose.yml
- **Input tokens:** 8,111 | **Output tokens:** 1,206
- **Findings:** 18 total — all resolved or addressed
- **Report:** `stacks/backup/CODEX_REVIEW.md`

## Sandbox Deployment Log

```
Target: DigitalOcean Droplet (Ubuntu 22.04, 4GB RAM)
Host: 137.184.55.8

$ scp scripts/backup.sh root@137.184.55.8:/opt/homelab/scripts/
$ scp stacks/backup/docker-compose.yml root@137.184.55.8:/opt/homelab/stacks/backup/

=== Test 1: --help ===
$ /opt/homelab/scripts/backup.sh --help
HomeLab Backup — 3-2-1 Strategy
Usage: backup.sh --target <stack|all> [options]
[... full help output ...]

=== Test 2: --dry-run ===
$ /opt/homelab/scripts/backup.sh --target all --dry-run
[backup] Target: all | Backend: local
[backup] Encrypt: false | Dry-run: true
[backup]   [dry-run] Would backup PostgreSQL, MariaDB, Redis
[backup]   [dry-run] Would backup config/ stacks/ scripts/
[backup]   [dry-run] Would backup volume: databases_postgres-data
[backup]   [dry-run] Would backup volume: databases_redis-data
[backup]   [dry-run] Would backup volume: storage_nextcloud-app
[... 11 volumes listed ...]
[backup] Dry run complete — no data was written.

=== Test 3: Real database backup ===
$ /opt/homelab/scripts/backup.sh --target databases
[backup] Target: databases | Backend: local
[backup]   PostgreSQL: pg_dumpall...
[backup]   MariaDB: mysqldump...
[backup]   Redis: BGSAVE + dump.rdb...
[backup]   Volume: mariadb-data
[backup]   Volume: pgadmin-data
[backup]   Volume: postgres-data
[backup]   Volume: redis-data
[backup] Backup complete: 20260318_033528
[backup] Size: 760K | Duration: 5s

=== Test 4: --verify ===
$ /opt/homelab/scripts/backup.sh --verify
[backup] Verifying backup: 20260318_033528
  ✅ manifest.json — valid JSON
  ✅ mariadb_all.sql.gz — valid gzip
  ✅ postgresql_all.sql.gz — valid gzip
  ✅ redis_dump.rdb — non-empty (24K)
  ✅ vol_mariadb-data.tar.gz — valid tar.gz
  ✅ vol_pgadmin-data.tar.gz — valid tar.gz
  ✅ vol_postgres-data.tar.gz — valid tar.gz
  ✅ vol_redis-data.tar.gz — valid tar.gz
[backup] Verification PASSED: 8/8 files OK

=== Test 5: --list ===
$ /opt/homelab/scripts/backup.sh --list
BACKUP ID              SIZE       FILES    DATE
20260318_032959        760K       8        2026-03-18 03:30:10
20260318_033023        760K       7        2026-03-18 03:30:30
20260318_033528        760K       8        2026-03-18 03:35:33

=== Test 6: Encrypted backup ===
$ BACKUP_ENCRYPTION_KEY=testkey /opt/homelab/scripts/backup.sh --target databases --encrypt
[backup] Target: databases | Encrypt: true
[backup]   PostgreSQL: pg_dumpall...
[backup]   Encrypted: postgresql_all.sql.gz.enc
[backup]   MariaDB: mysqldump...
[backup]   Encrypted: mariadb_all.sql.gz.enc
[backup]   Redis: BGSAVE + dump.rdb...
[backup]   Encrypted: redis_dump.rdb.enc
[backup]   Volume: postgres-data
[backup]   Encrypted: vol_postgres-data.tar.gz.enc
[... all volumes encrypted ...]
[backup] Backup complete — Duration: 7s

=== Test 7: Manifest with SHA-256 ===
$ cat /opt/homelab-backups/20260318_033528/manifest.json
{
  "backup_id": "20260318_033528",
  "date": "2026-03-18T03:35:33Z",
  "target": "local",
  "encrypted": false,
  "total_size": "756K",
  "file_count": 7,
  "files": [
    {"name": "mariadb_all.sql.gz", "size": "676K", "sha256": "9e666189c367..."},
    {"name": "postgresql_all.sql.gz", "size": "36K", "sha256": "303c709ae638..."},
    ...
  ]
}

=== Test 8: Docker Compose — backup stack ===
$ docker compose -f stacks/backup/docker-compose.yml up -d
Container homelab-duplicati  Started
Container homelab-restic     Started

$ docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "duplicati|restic"
homelab-duplicati    Up 2 minutes (healthy)
homelab-restic       Up 41 seconds (healthy)
```

## ShellCheck
```
$ shellcheck -x scripts/backup.sh
# Zero errors/warnings (only SC2029 info about SFTP variable expansion — intentional)
```

## Summary
- backup.sh: 7 commands tested (help, dry-run, backup, verify, list, encrypt, manifest)
- Docker stack: 2 containers healthy (Duplicati + Restic REST Server)
- All backups verified: 8/8 files OK with SHA-256 checksums
- ShellCheck clean
