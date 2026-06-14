#!/usr/bin/env bash
set -e

echo "======================================"
echo " Starting Full-Stack Automated Tests"
echo "======================================"

cd "$(dirname "$0")/.."

bash tests/test_scripts.sh
bash tests/test_compose.sh

echo "======================================"
echo " 🎉 All tests passed successfully!"
echo "======================================"
