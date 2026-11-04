#!/usr/bin/env bash
set -euo pipefail

CMD=${1:-}

check_status() {
  if systemctl is-active --quiet systemd-resolved; then
    echo "systemd-resolved is running."
  else
    echo "systemd-resolved is stopped."
  fi
}

apply_fix() {
  echo "Disabling systemd-resolved stub listener..."
  sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
  sudo systemctl restart systemd-resolved
  echo "Done. Port 53 is now free."
}

restore() {
  echo "Restoring systemd-resolved stub listener..."
  sudo sed -i 's/DNSStubListener=no/#DNSStubListener=yes/' /etc/systemd/resolved.conf
  sudo systemctl restart systemd-resolved
}

case "$CMD" in
  --check) check_status ;;
  --apply) apply_fix ;;
  --restore) restore ;;
  *) echo "Usage: $0 {--check|--apply|--restore}" ;;
esac