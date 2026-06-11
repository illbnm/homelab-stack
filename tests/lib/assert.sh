#!/bin/bash
assert_http_200() { curl -s -o /dev/null -w "%{http_code}" "$1" | grep -q 200 || { echo "FAIL: $1"; exit 1; }; }
assert_eq() { [ "$1" == "$2" ] || { echo "FAIL: $1 != $2"; exit 1; }; }
