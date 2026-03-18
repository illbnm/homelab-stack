# Live Test Results — Storage Stack

Tested: 2026-03-18
Server: DigitalOcean sandbox (137.184.55.8)
Docker: 29.3.0 / Compose v5.1.0

---

## Container Health

All services running and healthy:

```
NAME                      STATUS
homelab-filebrowser       Up (healthy)
homelab-minio             Up (healthy)
homelab-minio-init        Exited (0) — completed successfully
homelab-nextcloud         Up (healthy)
homelab-nextcloud-cron    Up
homelab-nextcloud-nginx   Up (healthy)
homelab-syncthing         Up (healthy)
```

## Test 1: Nextcloud Auto-Install

Nextcloud automatically installed using environment variables on first start:

```json
{
  "installed": true,
  "version": "29.0.7.1",
  "versionstring": "29.0.7",
  "maintenance": false,
  "needsDbUpgrade": false
}
```

Admin user created: `admin` (enabled: true)

## Test 2: Nextcloud -> PostgreSQL

```
PostgreSQL: connected
```

Nextcloud connects to `homelab-postgres:5432/nextcloud` via the `databases` network.

## Test 3: Nextcloud -> Redis DB 3

```
Redis DB 3: pass
```

Redis used for file locking and caching on allocated DB 3.

## Test 4: Nextcloud Nginx -> FPM Proxy

```
installed: True
version: 29.0.7
```

Nginx successfully proxies PHP requests to Nextcloud FPM via `storage-internal` network.

## Test 5: MinIO Health

```
MinIO API: healthy
Console: HTTP 200
```

## Test 6: MinIO Buckets

4 default buckets created by init container:

```
[2026-03-18 01:37:26 UTC]     0B backups/
[2026-03-18 01:37:26 UTC]     0B documents/
[2026-03-18 01:37:26 UTC]     0B media/
[2026-03-18 01:37:26 UTC]     0B nextcloud/
```

## Test 7: FileBrowser

```json
{"status": "OK"}
```

## Test 8: Syncthing

```json
{"status": "OK"}
```

## Test 9: Syncthing P2P Ports

```
22000/tcp: LISTENING
22000/udp: LISTENING
21027/udp: LISTENING
```

## Test 10: Network Isolation

```
Nextcloud FPM on proxy network:  NO  (internal only — correct)
Nextcloud Nginx on proxy network: YES (Traefik accessible — correct)
MinIO on proxy network:           YES (Traefik accessible — correct)
FileBrowser on proxy network:     YES (Traefik accessible — correct)
Syncthing on proxy network:       YES (Traefik accessible — correct)
storage-internal is internal:     true (no egress — correct)
```

---

## Summary

| Test | Result |
|------|--------|
| Container health (6/6 + 1 init) | PASS |
| Nextcloud auto-install | PASS |
| Nextcloud -> PostgreSQL | PASS |
| Nextcloud -> Redis DB 3 | PASS |
| Nextcloud Nginx -> FPM proxy | PASS |
| Nextcloud admin user | PASS |
| MinIO health (API + Console) | PASS |
| MinIO buckets (4/4) | PASS |
| FileBrowser health | PASS |
| Syncthing health | PASS |
| Syncthing P2P ports (3/3) | PASS |
| Network isolation | PASS |
| storage-internal is internal | PASS |

All 13 tests passed.
