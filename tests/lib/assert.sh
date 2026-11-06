#!/bin/bash

assert_eq() {
    if [ "$1" == "$2" ]; then
        echo "[PASS] $3"
    else
        echo "[FAIL] $3: Expected $2, got $1"
        exit 1
    fi
}

assert_http_code() {
    local code=$(curl -s -o /dev/null -w "%{http_code}" "$1")
    if [ "$code" == "$2" ]; then
        echo "[PASS] HTTP $1 is $2"
    else
        echo "[FAIL] HTTP $1 expected $2, got $code"
        exit 1
    fi
}