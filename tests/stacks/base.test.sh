#!/bin/bash
source tests/lib/assert.sh
echo "Testing Base Infrastructure..."
assert_http_200 http://localhost
assert_http_200 https://localhost
echo "Base tests passed."
