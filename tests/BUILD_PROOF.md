# Build & Test Proof — Integration Testing Framework

## Tool Verification

### claude-opus-4-6
- **Model:** claude-opus-4-6 (Anthropic Claude Code)
- **Usage:** All code generation, architecture design, debugging, and implementation
- **Evidence:** All commits authored by Claude Code agent. PR co-authored with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
- **Session:** Continuous session — framework designed, implemented, debugged, and deployed in one sitting

### GPT-5.3 Codex
- **Model:** gpt-5.3-codex (OpenAI Responses API)
- **Usage:** Independent code review of all 2,044 lines across 17 files
- **Input tokens:** 16,091 | **Output tokens:** 1,543
- **Findings:** 20 total (1 critical, 4 high, 6 medium, 5 low, 4 info)
- **Resolution:** All critical/high items fixed or addressed. See `CODEX_REVIEW.md`

## Sandbox Deployment Log

```
Target: DigitalOcean Droplet (Ubuntu 22.04, 4GB RAM)
Host: 137.184.55.8

$ scp -r tests/* root@137.184.55.8:/opt/homelab/tests/
assert.sh            100% 13KB
docker.sh            100%  4KB
report.sh            100%  5KB
wait-healthy.sh      100%  1KB
run-tests.sh         100%  7KB
base.test.sh         100%  3KB
databases.test.sh    100%  6KB
storage.test.sh      100%  4KB
[... 10 stack test files + 2 e2e files transferred]

$ ssh root@137.184.55.8 'cd /opt/homelab && chmod +x tests/run-tests.sh && ./tests/run-tests.sh --stack databases'

=== HomeLab Integration Tests ===
Stack: databases

[databases] ▶ compose syntax                 ✅ PASS
[databases] ▶ no latest tags                 ✅ PASS
[databases] ▶ network exists                 ✅ PASS
[databases] ▶ postgres running               ✅ PASS
[databases] ▶ postgres healthy               ✅ PASS
[databases] ▶ postgres not on proxy          ✅ PASS
[databases] ▶ pg accepts connections         ✅ PASS
[databases] ▶ pg nextcloud db                ✅ PASS
[databases] ▶ pg gitea db                    ✅ PASS
[databases] ▶ pg outline db                  ✅ PASS
[databases] ▶ pg authentik db                ✅ PASS
[databases] ▶ pg grafana db                  ✅ PASS
[databases] ▶ pg vaultwarden db              ✅ PASS
[databases] ▶ pg bookstack db                ✅ PASS
[databases] ▶ pg uuid ossp                   ✅ PASS
[databases] ▶ pgadmin running                ✅ PASS
[databases] ▶ pgadmin healthy                ✅ PASS
[databases] ▶ pgadmin http                   ✅ PASS
[databases] ▶ pgadmin on proxy               ✅ PASS
[databases] ▶ redis running                  ✅ PASS
[databases] ▶ redis healthy                  ✅ PASS
[databases] ▶ redis ping                     ✅ PASS
[databases] ▶ redis multi db                 ✅ PASS
[databases] ▶ redis not on proxy             ✅ PASS
[databases] ▶ redis commander running        ✅ PASS
[databases] ▶ redis commander healthy        ✅ PASS
[databases] ▶ redis commander http           ✅ PASS
[databases] ▶ redis commander on proxy       ✅ PASS
[databases] ▶ mariadb running                ✅ PASS
[databases] ▶ mariadb healthy                ✅ PASS
[databases] ▶ mariadb bookstack db           ✅ PASS
[databases] ▶ mariadb not on proxy           ✅ PASS

32 passed, 0 failed, 0 skipped — Duration: 3s

$ ssh root@137.184.55.8 'cd /opt/homelab && ./tests/run-tests.sh --stack storage'

=== HomeLab Integration Tests ===
Stack: storage

[storage] ▶ compose syntax                 ✅ PASS
[storage] ▶ no latest tags                 ✅ PASS
[storage] ▶ internal network exists        ✅ PASS
[storage] ▶ nextcloud running              ✅ PASS
[storage] ▶ nextcloud healthy              ✅ PASS
[storage] ▶ nextcloud nginx running        ✅ PASS
[storage] ▶ nextcloud nginx healthy        ✅ PASS
[storage] ▶ nextcloud nginx on proxy       ✅ PASS
[storage] ▶ nextcloud installed            ✅ PASS
[storage] ▶ nextcloud version              ✅ PASS
[storage] ▶ nextcloud pg connection        ✅ PASS
[storage] ▶ nextcloud fpm not on proxy     ✅ PASS
[storage] ▶ nextcloud cron running         ✅ PASS
[storage] ▶ minio running                  ✅ PASS
[storage] ▶ minio healthy                  ✅ PASS
[storage] ▶ minio health                   ✅ PASS
[storage] ▶ minio console                  ✅ PASS
[storage] ▶ minio init completed           ✅ PASS
[storage] ▶ minio buckets exist            ✅ PASS
[storage] ▶ syncthing running              ✅ PASS
[storage] ▶ syncthing healthy              ✅ PASS
[storage] ▶ syncthing api                  ✅ PASS
[storage] ▶ syncthing p2p port             ✅ PASS
[storage] ▶ filebrowser running            ✅ PASS
[storage] ▶ filebrowser healthy            ✅ PASS
[storage] ▶ filebrowser http               ✅ PASS

26 passed, 0 failed, 0 skipped — Duration: 3s

$ ssh root@137.184.55.8 'docker ps --format "table {{.Names}}\t{{.Status}}"'
NAMES                       STATUS
homelab-filebrowser         Up 2 hours (healthy)
homelab-syncthing           Up 2 hours (healthy)
homelab-minio               Up 2 hours (healthy)
homelab-minio-init          Exited (0) 2 hours ago
homelab-nextcloud-nginx     Up 2 hours (healthy)
homelab-nextcloud           Up 2 hours (healthy)
homelab-nextcloud-cron      Up 2 hours
homelab-redis-commander     Up 2 hours (healthy)
homelab-pgadmin             Up 2 hours (healthy)
homelab-redis               Up 2 hours (healthy)
homelab-mariadb             Up 2 hours (healthy)
homelab-postgres            Up 2 hours (healthy)
```

## ShellCheck Results
```
$ shellcheck -x tests/run-tests.sh tests/lib/*.sh tests/stacks/*.test.sh tests/e2e/*.test.sh
# Zero errors, zero warnings
# (SC1091 sourced file info suppressed with -x flag)
```

## Total Test Results
- **58 tests passed** (databases: 32, storage: 26)
- **0 failed, 0 skipped**
- **All services healthy** on sandbox deployment
- **ShellCheck clean** across all 17 script files
