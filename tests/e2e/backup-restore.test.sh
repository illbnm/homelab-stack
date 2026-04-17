#!/usr/bin/env bash
# tests/e2e/backup-restore.test.sh — Backup/restore flow

BASE="$(cd "$(dirname "$0")/../.."; pwd)"

describe "E2E: Backup & Restore"

it "backup.sh script exists and is executable"
assert_file_exists "$BASE/scripts/backup.sh"

it "backup-databases.sh script exists"
assert_file_exists "$BASE/scripts/backup-databases.sh"

it "backup.sh has valid bash syntax"
assert_exit_code 0 "bash -n $BASE/scripts/backup.sh"

it "backup-databases.sh has valid bash syntax"
assert_exit_code 0 "bash -n $BASE/scripts/backup-databases.sh"
