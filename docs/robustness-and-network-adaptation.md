# Robustness & CN Network Adaptation

Comprehensive tooling ensuring 100% reliable deployment of HomeLab Stack in challenging or restricted network environments, with specific domestic optimization for mainland China.

## Included Utilities

- `scripts/localize-images.sh`: Dynamic image registry substitution (`--cn`, `--restore`, `--dry-run`, `--check`).
- `config/cn-mirrors.yml`: Verified upstream-to-mirror mappings.
- `scripts/check-connectivity.sh`: Automated latency and packet loss diagnostic.
- `install.sh`: Production-grade self-healing host installer with `curl_retry` exponential backoff.
- `scripts/wait-healthy.sh`: Robust container health supervisor with failure logs extraction.
- `scripts/diagnose.sh`: Instant one-click diagnostic telemetry packager.
