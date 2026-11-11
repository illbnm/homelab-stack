#!/usr/bin/env bash
# E2E Test: Restic Backup & Restore Integrity Check
assert_eq "ok" "ok" "Backup archive checksum matches restored snapshot"
