#!/bin/bash
set -e
echo "Running HomeLab Stack integration tests..."
for test in tests/stacks/*.test.sh; do
  echo "Executing $test..."
  bash "$test"
done
echo "All tests passed."
