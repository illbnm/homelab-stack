# Robustness and China network adaptation

This repository includes helper scripts for restricted or slow network environments and for production diagnostics.

## Mainland China Docker mirrors

```bash
./scripts/setup-cn-mirrors.sh --yes
./scripts/localize-images.sh --cn
```

`setup-cn-mirrors.sh` writes Docker registry mirrors to `/etc/docker/daemon.json`, restarts Docker when possible, and verifies with `docker pull hello-world`.

`localize-images.sh --cn` rewrites blocked registries in compose files using `config/cn-mirrors.yml`. Use `--dry-run` first to preview changes, `--check` to verify no `gcr.io` or `ghcr.io` images remain, and `--restore` to revert from the last backup.

## Package mirrors

For services or entrypoints that install packages at runtime, print the mirror snippet and source it before package installation:

```bash
./scripts/setup-package-mirrors.sh --print-entrypoint
```

For host-level package manager acceleration:

```bash
./scripts/setup-package-mirrors.sh --host
```

Ubuntu/Debian use the Tsinghua apt mirror, pip uses the Tsinghua PyPI mirror, and Alpine uses the USTC mirror.

## Connectivity and diagnostics

```bash
./scripts/check-connectivity.sh
./scripts/diagnose.sh
```

`check-connectivity.sh` reports OK/SLOW/FAIL for Docker Hub, GitHub, gcr.io, ghcr.io, DNS, and outbound HTTP/HTTPS.

`diagnose.sh` writes a diagnostic report under `diagnostics/` with Docker version, OS/kernel/memory/disk details, container status, recent error logs, connectivity results, and compose validation.

## Stack readiness

```bash
./scripts/wait-healthy.sh --stack base --timeout 300
```

Exit codes:

- `0`: all containers are running and healthy, or running without a healthcheck
- `1`: timed out waiting for health
- `2`: at least one container exited

On timeout, the script prints the last 50 log lines from stack containers.
