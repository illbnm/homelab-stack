#!/usr/bin/env bash
set -e

echo "Running shell script validation tests..."
ERRORS=0

for script in install.sh scripts/*.sh; do
    if [ -f "$script" ]; then
        if ! bash -n "$script"; then
            echo "❌ Syntax error in $script"
            ERRORS=$((ERRORS+1))
        else
            echo "✅ Syntax check passed for $script"
        fi
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo "Failed script tests: $ERRORS"
    exit 1
fi

echo "All shell scripts are valid!"
