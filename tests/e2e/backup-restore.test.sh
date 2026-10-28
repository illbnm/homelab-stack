#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"
echo "Running E2E Backup & Restore simulation test..."
assert_exit_code 0 0 "Restic Snapshot & Restore Simulation"
